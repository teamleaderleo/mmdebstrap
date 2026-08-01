#!/usr/bin/env python3

import sys
import os
import time
import http.client
import http.server
from io import StringIO
import pathlib
import urllib.parse
import contextlib
import secrets

oldcachedir = None
newcachedir = None
readonly = False


HOP_BY_HOP_REQUEST_HEADERS = {
    "connection",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "proxy-connection",
    "te",
    "trailer",
    "transfer-encoding",
    "upgrade",
}

HOP_BY_HOP_RESPONSE_HEADERS = HOP_BY_HOP_REQUEST_HEADERS


def request_context(root, request_target, host):
    parsed = urllib.parse.urlsplit(request_target)
    try:
        host_parsed = urllib.parse.urlsplit("//" + host)
        request_port = parsed.port or 80
        host_port = host_parsed.port or 80
    except ValueError as error:
        raise ValueError("invalid proxy request target") from error
    if (
        parsed.scheme.lower() != "http"
        or parsed.username is not None
        or parsed.password is not None
        or parsed.hostname is None
        or host_parsed.username is not None
        or host_parsed.password is not None
        or host_parsed.hostname is None
        or host_parsed.path
        or host_parsed.query
        or host_parsed.fragment
        or parsed.hostname.lower() != host_parsed.hostname.lower()
        or request_port != host_port
        or parsed.query
        or parsed.fragment
        or not parsed.path.startswith("/")
    ):
        raise ValueError("invalid proxy request target")
    raw_path = parsed.path[1:]
    if not raw_path or "%" in raw_path or "\\" in raw_path or "\0" in raw_path:
        raise ValueError("unsafe cache path")
    components = raw_path.split("/")
    if any(part in ("", ".", "..") for part in components):
        raise ValueError("unsafe cache path")
    relative = pathlib.PurePosixPath(*components)
    resolved_root = root.resolve()
    candidate = (resolved_root / pathlib.Path(*relative.parts)).resolve()
    if candidate == resolved_root or not candidate.is_relative_to(resolved_root):
        raise ValueError("unsafe cache path")
    return candidate, parsed.hostname, request_port


def origin_request_headers(headers):
    connection_tokens = set()
    for value in headers.get_all("Connection", []):
        connection_tokens.update(
            token.strip().lower()
            for token in value.split(",")
            if token.strip()
        )
    if "host" in connection_tokens:
        raise ValueError("Host cannot be a connection-specific field")
    blocked = HOP_BY_HOP_REQUEST_HEADERS | connection_tokens
    result = [
        (name, value)
        for name, value in headers.raw_items()
        if name.lower() not in blocked
    ]
    result.append(("Connection", "close"))
    return result


def validate_transfer_encoding(response):
    values = response.headers.get_all("Transfer-Encoding", [])
    if not values:
        return
    tokens = [
        token.strip().lower()
        for value in values
        for token in value.split(",")
        if token.strip()
    ]
    if tokens != ["chunked"] or not response.chunked:
        raise ValueError("unsupported upstream Transfer-Encoding")


def downstream_headers(response):
    headers = response.getheaders()
    connection_tokens = set()
    for name, value in headers:
        if name.lower() == "connection":
            connection_tokens.update(
                token.strip().lower()
                for token in value.split(",")
                if token.strip()
            )
    blocked = HOP_BY_HOP_RESPONSE_HEADERS | connection_tokens
    if response.chunked:
        blocked = blocked | {"content-length"}
    return [
        (name, value)
        for name, value in headers
        if name.lower() not in blocked
    ]


def new_cache_temporary(path):
    for _ in range(100):
        temporary = path.with_name(
            f".{path.name}.{secrets.token_hex(12)}"
        )
        try:
            descriptor = os.open(
                temporary,
                os.O_WRONLY | os.O_CREAT | os.O_EXCL,
                0o666,
            )
        except FileExistsError:
            continue
        return descriptor, temporary
    raise FileExistsError(f"unable to allocate temporary cache file for {path}")


@contextlib.contextmanager
def cache_destination(path):
    if path == pathlib.Path("/dev/null"):
        with path.open(mode="wb") as cache:
            yield cache
        return
    descriptor, temporary = new_cache_temporary(path)
    try:
        with os.fdopen(descriptor, mode="wb") as cache:
            yield cache
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


class ProxyRequestHandler(http.server.BaseHTTPRequestHandler):
    def reject_method(self):
        self.send_error(405, "method not allowed")

    do_CONNECT = reject_method
    do_DELETE = reject_method
    do_HEAD = reject_method
    do_OPTIONS = reject_method
    do_PATCH = reject_method
    do_POST = reject_method
    do_PUT = reject_method
    do_TRACE = reject_method

    def do_GET(self):
        host_values = self.headers.get_all("Host", [])
        content_length_values = self.headers.get_all("Content-Length", [])
        if (
            len(host_values) != 1
            or len(content_length_values) > 1
            or self.headers.get_all("Transfer-Encoding", [])
        ):
            self.send_error(400, "invalid proxy request")
            return
        if content_length_values:
            content_length_text = content_length_values[0]
            if not content_length_text or any(
                character < "0" or character > "9"
                for character in content_length_text
            ):
                self.send_error(400, "invalid Content-Length")
                return
            content_length = int(content_length_text)
        else:
            content_length = 0
        if content_length != 0:
            self.send_error(400, "invalid proxy request")
            return

        host = host_values[0]
        try:
            oldpath, origin_host, origin_port = request_context(
                oldcachedir, self.path, host
            )
            newpath, second_host, second_port = request_context(
                newcachedir, self.path, host
            )
            if (origin_host, origin_port) != (second_host, second_port):
                raise ValueError("inconsistent proxy request authority")
            origin_headers = origin_request_headers(self.headers)
        except ValueError as error:
            self.send_error(400, str(error))
            return

        if not readonly:
            newpath.parent.mkdir(parents=True, exist_ok=True)

        # just send back to client
        if newpath.exists():
            print(f"proxy cached: {self.path}", file=sys.stderr)
            self.wfile.write(b"HTTP/1.1 200 OK\r\n")
            self.send_header("Content-Length", newpath.stat().st_size)
            self.end_headers()
            with newpath.open(mode="rb") as new:
                while True:
                    buf = new.read(64 * 1024)  # same as shutil uses
                    if not buf:
                        break
                    self.wfile.write(buf)
            self.wfile.flush()
            return

        if readonly:
            newpath = pathlib.Path("/dev/null")

        # copy from oldpath to newpath and send back to client
        # Only take files from the old cache if they are .deb files or Packages
        # files in the by-hash directory as only those are unique by their path
        # name. Other files like InRelease files have to be downloaded afresh.
        if oldpath.exists() and (
            oldpath.suffix == ".deb" or "by-hash" in oldpath.parts
        ):
            print(f"proxy cached: {self.path}", file=sys.stderr)
            self.wfile.write(b"HTTP/1.1 200 OK\r\n")
            self.send_header("Content-Length", oldpath.stat().st_size)
            self.end_headers()
            with oldpath.open(mode="rb") as old, cache_destination(newpath) as new:
                # we are not using shutil.copyfileobj() because we want to
                # write to two file objects simultaneously
                while True:
                    buf = old.read(64 * 1024)  # same as shutil uses
                    if not buf:
                        break
                    self.wfile.write(buf)
                    new.write(buf)
            self.wfile.flush()
            return

        # download fresh copy
        response_started = False
        conn = None
        try:
            print(f"\rproxy download: {self.path}", file=sys.stderr)
            conn = http.client.HTTPConnection(
                origin_host, origin_port, timeout=5
            )
            conn.putrequest(
                "GET", self.path, skip_host=True, skip_accept_encoding=True
            )
            for name, value in origin_headers:
                conn.putheader(name, value)
            conn.endheaders()
            res = conn.getresponse()
            if res.status != 200:
                raise http.client.HTTPException(
                    f"unexpected upstream response: {res.status} {res.reason}"
                )
            validate_transfer_encoding(res)
            expected_length = (
                None if res.chunked else res.getheader("Content-Length")
            )
            if expected_length is not None:
                if not expected_length or any(
                    character < "0" or character > "9"
                    for character in expected_length
                ):
                    raise ValueError("invalid upstream Content-Length")
                expected_length = int(expected_length)
            headers = downstream_headers(res)
            response_started = True
            self.wfile.write(b"HTTP/1.1 200 OK\r\n")
            for name, value in headers:
                self.send_header(name, value)
            self.send_header("Connection", "close")
            self.close_connection = True
            self.end_headers()
            with cache_destination(newpath) as cache:
                received = 0
                while True:
                    buf = res.read(64 * 1024)  # same as shutil uses
                    if not buf:
                        break
                    self.wfile.write(buf)
                    cache.write(buf)
                    received += len(buf)
                    time.sleep(64 / 1024)  # 1024 kB/s
                if expected_length is not None and received != expected_length:
                    raise http.client.IncompleteRead(
                        b"", expected_length - received
                    )
            self.wfile.flush()
        except Exception as error:
            print(f"proxy error: {error!r}", file=sys.stderr)
            if response_started:
                self.close_connection = True
                return
            self.send_error(502)
        finally:
            if conn is not None:
                conn.close()


def main():
    global oldcachedir, newcachedir, readonly
    if sys.argv[1] == "--readonly":
        readonly = True
        oldcachedir = pathlib.Path(sys.argv[2])
        newcachedir = pathlib.Path(sys.argv[3])
    else:
        oldcachedir = pathlib.Path(sys.argv[1])
        newcachedir = pathlib.Path(sys.argv[2])
    print(f"starting caching proxy for {newcachedir}", file=sys.stderr)
    httpd = http.server.ThreadingHTTPServer(
        server_address=("127.0.0.1", 8080), RequestHandlerClass=ProxyRequestHandler
    )
    httpd.serve_forever()


if __name__ == "__main__":
    main()
