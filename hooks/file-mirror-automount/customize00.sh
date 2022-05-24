#!/bin/sh

set -eu

if [ "$MMDEBSTRAP_VERBOSITY" -ge 3 ]; then
	set -x
fi

rootdir="$1"

if [ ! -e "$rootdir/run/mmdebstrap/file-mirror-automount" ]; then
	exit 0
fi

xargsopts="--null --no-run-if-empty -I {} --max-args=1"

echo "unmounting the following mountpoints:" >&2

cat "$rootdir/run/mmdebstrap/file-mirror-automount" \
	| xargs $xargsopts echo "    $rootdir/{}"

cat "$rootdir/run/mmdebstrap/file-mirror-automount" \
	| xargs $xargsopts umount "$rootdir/{}"

rm "$rootdir/run/mmdebstrap/file-mirror-automount"
rmdir --ignore-fail-on-non-empty "$rootdir/run/mmdebstrap"
