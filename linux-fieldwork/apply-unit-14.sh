#!/bin/sh
set -eu

expected_base_blob=6c4be092edcf23b56b63a3befe238c099c45f590
expected_patch_sha256=980720d262d0f5d4a568be54851e144652ae6d882a8ad0e8aa228c8ffed2ae42
patch_file=linux-fieldwork/0001-update-cache-worker-lifecycle.patch

usage() {
  echo "usage: $0 [--check|--apply]" >&2
  exit 2
}

mode=${1:---check}
case "$mode" in
  --check | --apply) ;;
  *) usage ;;
esac

[ -f make_mirror.sh ] || {
  echo "run from the repository root" >&2
  exit 1
}
[ -f "$patch_file" ] || {
  echo "missing patch: $patch_file" >&2
  exit 1
}

base_blob=$(git hash-object make_mirror.sh)
if [ "$base_blob" != "$expected_base_blob" ]; then
  echo "unexpected make_mirror.sh blob: $base_blob" >&2
  echo "expected: $expected_base_blob" >&2
  exit 1
fi

patch_sha256=$(sha256sum "$patch_file" | awk '{print $1}')
if [ "$patch_sha256" != "$expected_patch_sha256" ]; then
  echo "unexpected patch SHA-256: $patch_sha256" >&2
  echo "expected: $expected_patch_sha256" >&2
  exit 1
fi

patch --dry-run --fuzz=0 -p1 <"$patch_file"

if [ "$mode" = --check ]; then
  echo "unit 14 patch applies with zero fuzz to $base_blob"
  exit 0
fi

patch --fuzz=0 -p1 <"$patch_file"
/bin/sh -n make_mirror.sh
git diff --check -- make_mirror.sh

if sed -n '/^update_cache() (/,/^)/p' make_mirror.sh | grep -q 'PROXYPID'; then
  echo "update_cache still references parent-owned PROXYPID" >&2
  exit 1
fi

grep -F 'record_update_cache_cleanup_signal 130' make_mirror.sh >/dev/null
grep -F 'record_update_cache_cleanup_signal 131' make_mirror.sh >/dev/null
grep -F 'record_update_cache_cleanup_signal 143' make_mirror.sh >/dev/null
grep -F 'update_cache_finish 0' make_mirror.sh >/dev/null

candidate_blob=$(git hash-object make_mirror.sh)
echo "unit 14 patch applied; candidate make_mirror.sh blob: $candidate_blob"
