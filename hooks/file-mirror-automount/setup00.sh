#!/bin/sh

set -eu

if [ "$MMDEBSTRAP_VERBOSITY" -ge 3 ]; then
	set -x
fi

rootdir="$1"

env APT_CONFIG=$MMDEBSTRAP_APT_CONFIG apt-get indextargets --no-release-info --format '$(REPO_URI)' \
	| sed -ne 's/^file:\/\+//p' \
	| sort -u \
	| while read path; do
		mkdir -p "$rootdir/run/mmdebstrap"
		case $MMDEBSTRAP_MODE in
			root|unshare)
				echo "bind-mounting /$path into the chroot" >&2
				mkdir -p "$rootdir/$path"
				mount -o ro,bind "/$path" "$rootdir/$path"
				;;
			*)
				echo "copying /$path into the chroot" >&2
				mkdir -p "$rootdir/$(dirname $path)"
				cp -av "/$path" "$rootdir/$(dirname $path)"
				;;
		esac
		printf '/%s\0' "$path" >> "$rootdir/run/mmdebstrap/file-mirror-automount"
	done
