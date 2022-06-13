#!/usr/bin/env python3

from debian.deb822 import Deb822, Release
import email.utils
import os
import sys
import shutil
import subprocess
import argparse
import time
from datetime import timedelta
from collections import defaultdict

have_qemu = os.getenv("HAVE_QEMU", "yes") == "yes"
have_unshare = os.getenv("HAVE_UNSHARE", "yes") == "yes"
have_binfmt = os.getenv("HAVE_BINFMT", "yes") == "yes"
run_ma_same_tests = os.getenv("RUN_MA_SAME_TESTS", "yes") == "yes"
cmd = os.getenv("CMD", "./mmdebstrap")

default_dist = os.getenv("DEFAULT_DIST", "unstable")
all_dists = ["oldstable", "stable", "testing", "unstable"]
default_mode = "auto" if have_unshare else "root"
all_modes = ["auto", "root", "unshare", "fakechroot", "chrootless"]
default_variant = "apt"
all_variants = [
    "extract",
    "custom",
    "essential",
    "apt",
    "minbase",
    "buildd",
    "-",
    "standard",
]
default_format = "auto"
all_formats = ["auto", "directory", "tar", "squashfs", "ext2", "null"]

mirror = os.getenv("mirror", "http://127.0.0.1/debian")
hostarch = subprocess.check_output(["dpkg", "--print-architecture"]).decode().strip()

release_path = f"./shared/cache/debian/dists/{default_dist}/Release"
if not os.path.exists(release_path):
    print("path doesn't exist:", release_path, file=sys.stderr)
    print("run ./make_mirror.sh first", file=sys.stderr)
    exit(1)
if os.getenv("SOURCE_DATE_EPOCH") is not None:
    s_d_e = os.getenv("SOURCE_DATE_EPOCH")
else:
    with open(release_path) as f:
        rel = Release(f)
    s_d_e = str(email.utils.mktime_tz(email.utils.parsedate_tz(rel["Date"])))

separator = (
    "------------------------------------------------------------------------------"
)


def skip(condition, dist, mode, variant, fmt):
    if not condition:
        return ""
    for line in condition.splitlines():
        if not line:
            continue
        if eval(line):
            return line.strip()
    return ""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("test", nargs="*", help="only run these tests")
    parser.add_argument(
        "-x",
        "--exitfirst",
        action="store_const",
        dest="maxfail",
        const=1,
        help="exit instantly on first error or failed test.",
    )
    parser.add_argument(
        "--maxfail",
        metavar="num",
        action="store",
        type=int,
        dest="maxfail",
        default=0,
        help="exit after first num failures or errors.",
    )
    parser.add_argument("--mode", metavar="mode", help="only run tests with this mode")
    parser.add_argument("--dist", metavar="dist", help="only run tests with this dist")
    args = parser.parse_args()

    # copy over files from git or as distributed
    for (git, dist, target) in [
        ("./mmdebstrap", "/usr/bin/mmdebstrap", "mmdebstrap"),
        ("./taridshift", "/usr/bin/mmtaridshift", "taridshift"),
        ("./tarfilter", "/usr/bin/mmtarfilter", "tarfilter"),
        (
            "./proxysolver",
            "/usr/lib/apt/solvers/mmdebstrap-dump-solution",
            "proxysolver",
        ),
        (
            "./ldconfig.fakechroot",
            "/usr/libexec/mmdebstrap/ldconfig.fakechroot",
            "ldconfig.fakechroot",
        ),
    ]:
        if os.path.exists(git):
            shutil.copy(git, f"shared/{target}")
        else:
            shutil.copy(dist, f"shared/{target}")
    # copy over hooks from git or as distributed
    if os.path.exists("hooks"):
        shutil.copytree("hooks", "shared/hooks", dirs_exist_ok=True)
    else:
        shutil.copytree(
            "/usr/share/mmdebstrap/hooks", "shared/hooks", dirs_exist_ok=True
        )

    tests = []
    with open("coverage.txt") as f:
        for test in Deb822.iter_paragraphs(f):
            name = test["Test"]
            dists = test.get("Dists", default_dist)
            if dists == "any":
                dists = all_dists
            elif dists == "default":
                dists = [default_dist]
            else:
                dists = dists.split()
            modes = test.get("Modes", default_mode)
            if modes == "any":
                modes = all_modes
            elif modes == "default":
                modes = [default_mode]
            else:
                modes = modes.split()
            variants = test.get("Variants", default_variant)
            if variants == "any":
                variants = all_variants
            elif variants == "default":
                variants = [default_variant]
            else:
                variants = variants.split()
            formats = test.get("Formats", default_format)
            if formats == "any":
                formats = all_formats
            elif formats == "default":
                formats = [default_format]
            else:
                formats = formats.split()
            for dist in dists:
                for mode in modes:
                    for variant in variants:
                        for fmt in formats:
                            skipreason = skip(
                                test.get("Skip-If"), dist, mode, variant, fmt
                            )
                            if skipreason:
                                tt = ("skip", skipreason)
                            elif have_qemu:
                                tt = "qemu"
                            elif test.get("Needs-QEMU", "false") == "true":
                                tt = ("skip", "test needs QEMU")
                            elif test.get("Needs-Root", "false") == "true":
                                tt = "sudo"
                            elif mode == "auto" and not have_unshare:
                                tt = "sudo"
                            elif mode == "root":
                                tt = "sudo"
                            elif mode == "unshare" and not have_unshare:
                                tt = ("skip", "test needs unshare")
                            else:
                                tt = "null"
                            tests.append((tt, name, dist, mode, variant, fmt))

    torun = []
    num_tests = len(tests)
    if args.test:
        # check if all given tests are either a valid name or a valid number
        for test in args.test:
            if test in [name for (_, name, _, _, _, _) in tests]:
                continue
            if not test.isdigit():
                print(f"cannot find test named {test}", file=sys.stderr)
                exit(1)
            if int(test) >= len(tests) or int(test) <= 0 or str(int(test)) != test:
                print(f"test number {test} doesn't exist", file=sys.stderr)
                exit(1)

        for i, (_, name, _, _, _, _) in enumerate(tests):
            # if either the number or test name matches, then we use this test,
            # otherwise we skip it
            if name in args.test:
                torun.append(i)
            if str(i + 1) in args.test:
                torun.append(i)
        num_tests = len(torun)

    starttime = time.time()
    skipped = defaultdict(list)
    failed = []
    num_success = 0
    num_finished = 0
    for i, (test, name, dist, mode, variant, fmt) in enumerate(tests):
        if torun and i not in torun:
            continue
        print(separator, file=sys.stderr)
        print("(%d/%d) %s" % (i + 1, len(tests), name), file=sys.stderr)
        print("dist: %s" % dist, file=sys.stderr)
        print("mode: %s" % mode, file=sys.stderr)
        print("variant: %s" % variant, file=sys.stderr)
        print("format: %s" % fmt, file=sys.stderr)
        if num_finished > 0:
            currenttime = time.time()
            timeleft = timedelta(
                seconds=int(
                    (num_tests - num_finished)
                    * (currenttime - starttime)
                    / num_finished
                )
            )
            print("time left: %s" % timeleft, file=sys.stderr)
        if failed:
            print("failed: %d" % len(failed))
        num_finished += 1
        with open("tests/" + name) as fin, open("shared/test.sh", "w") as fout:
            for line in fin:
                line = line.replace("{{ CMD }}", cmd)
                line = line.replace("{{ SOURCE_DATE_EPOCH }}", s_d_e)
                line = line.replace("{{ DIST }}", dist)
                line = line.replace("{{ MIRROR }}", mirror)
                line = line.replace("{{ MODE }}", mode)
                line = line.replace("{{ VARIANT }}", variant)
                line = line.replace("{{ FORMAT }}", fmt)
                line = line.replace("{{ HOSTARCH }}", hostarch)
                fout.write(line)
        argv = None
        match test:
            case "qemu":
                argv = ["./run_qemu.sh"]
            case "sudo":
                argv = ["./run_null.sh", "SUDO"]
            case "null":
                argv = ["./run_null.sh"]
            case ("skip", reason):
                skipped[reason].append(
                    ("(%d/%d) %s" % (i + 1, len(tests), name), dist, mode, variant, fmt)
                )
                print(f"skipped because of {reason}", file=sys.stderr)
                continue
        print(separator, file=sys.stderr)
        if args.dist and args.dist != dist:
            print(f"skipping because of --dist={args.dist}", file=sys.stderr)
            continue
        if args.mode and args.mode != mode:
            print(f"skipping because of --mode={args.mode}", file=sys.stderr)
            continue
        proc = subprocess.Popen(argv)
        try:
            proc.wait()
        except KeyboardInterrupt:
            proc.terminate()
            proc.wait()
            break
        print(separator, file=sys.stderr)
        if proc.returncode != 0:
            failed.append(
                ("(%d/%d) %s" % (i + 1, len(tests), name), dist, mode, variant, fmt)
            )
            print("result: FAILURE", file=sys.stderr)
        else:
            print("result: SUCCESS", file=sys.stderr)
            num_success += 1
        if args.maxfail and len(failed) >= args.maxfail:
            break
    print(
        "successfully ran %d tests" % num_success,
        file=sys.stderr,
    )
    if skipped:
        print("skipped %d:" % sum([len(v) for v in skipped.values()]), file=sys.stderr)
        for reason, l in skipped.items():
            print(f"skipped because of {reason}:", file=sys.stderr)
            for t in l:
                print(f"    {t}", file=sys.stderr)
    if failed:
        print("failed %d:" % len(failed), file=sys.stderr)
        for t in failed:
            print(f"    {t}", file=sys.stderr)
        exit(1)


if __name__ == "__main__":
    main()
