#!/bin/sh
#
# shellcheck disable=SC2086

set -eu

if [ "${MMDEBSTRAP_VERBOSITY:-1}" -ge 3 ]; then
	set -x
fi

rootdir="$(realpath -e -- "$1")"
case "$rootdir" in
	/) echo "E: refusing filesystem root as generated root" >&2; exit 1 ;;
esac
marker="$rootdir/run/mmdebstrap/file-mirror-automount"

if [ ! -e "$marker" ]; then
	exit 0
fi

cleanup_entry='set -eu
rootdir=$1
mode=$2
entry=$3
case "$entry" in
	""|/*|*/) echo "E: unsafe file-mirror marker entry: $entry" >&2; exit 1 ;;
esac
case "/$entry/" in
	*"/../"*|*"/./"*|*"//"*) echo "E: unsafe file-mirror marker entry: $entry" >&2; exit 1 ;;
esac
target=$(realpath -m -- "$rootdir/$entry")
case "$target" in
	"$rootdir"/*) : ;;
	*) echo "E: file-mirror marker escapes root: $entry" >&2; exit 1 ;;
esac
case $mode in
	validate) : ;;
	root|unshare)
		echo "    $target" >&2
		umount "$target"
		;;
	*)
		echo "    $target" >&2
		rm -r "$target"
		;;
esac'

case $MMDEBSTRAP_MODE in
	root|unshare)
		echo "unmounting the following mountpoints:" >&2 ;;
	*)
		echo "removing the following directories:" >&2 ;;
esac

< "$marker" xargs --null --no-run-if-empty --max-args=1 \
	sh -c "$cleanup_entry" sh "$rootdir" validate
< "$marker" xargs --null --no-run-if-empty --max-args=1 \
	sh -c "$cleanup_entry" sh "$rootdir" "$MMDEBSTRAP_MODE"

rm "$marker"
rmdir --ignore-fail-on-non-empty "$rootdir/run/mmdebstrap"
