#!/bin/sh

set -eu

if [ "$MMDEBSTRAP_VERBOSITY" -ge 3 ]; then
	set -x
fi

rootdir="$1"

env APT_CONFIG=$MMDEBSTRAP_APT_CONFIG apt-get indextargets --no-release-info \
	| sed -ne 's/^Repo-URI: file:\/\+//p' \
	| sort -u \
	| while read path; do
		echo "bind-mounting /$path into the chroot" >&2
		mkdir -p "$rootdir/run/mmdebstrap"
		mkdir -p "$rootdir/$path"
		mount -o ro,bind "/$path" "$rootdir/$path"
		printf '/%s\0' "$path" >> "$rootdir/run/mmdebstrap/file-mirror-automount"
	done
