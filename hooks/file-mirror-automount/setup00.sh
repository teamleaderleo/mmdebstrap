#!/bin/sh

set -eu

if [ "${MMDEBSTRAP_VERBOSITY:-1}" -ge 3 ]; then
	set -x
fi

rootdir="$(realpath -e -- "$1")"
case "$rootdir" in
	/) echo "E: refusing filesystem root as generated root" >&2; exit 1 ;;
esac

resolve_contained_target() {
	canonical_source="$(realpath -e -- "$1")" || return 1
	case "$canonical_source" in
		/*) : ;;
		*) return 1 ;;
	esac
	case $# in
		1) target_source=$canonical_source ;;
		2) target_source=$2 ;;
		*) return 1 ;;
	esac
	normalized_target="$(realpath -m -s -- "$target_source")" || return 1
	case "$normalized_target" in
		/*) : ;;
		*) return 1 ;;
	esac
	target_relative=${normalized_target#/}
	[ -n "$target_relative" ] || return 1
	canonical_target="$(realpath -m -- "$rootdir/$target_relative")" || return 1
	case "$canonical_target" in
		"$rootdir"/*) : ;;
		*) return 1 ;;
	esac
	target_relative=${canonical_target#"$rootdir"/}
}

safe_repo_path() {
	path=$1
	while [ "${path%/}" != "$path" ]; do
		path=${path%/}
	done
	case "$path" in
		""|/*|..|../*) return 1 ;;
	esac
	case "/$path/" in
		*"/../"*) return 1 ;;
	esac
	printf '%s\n' "$path"
}

record_target() {
	mkdir -p "$rootdir/run/mmdebstrap"
	printf '%s\0' "$target_relative" >> "$rootdir/run/mmdebstrap/file-mirror-automount"
}

# process all configured apt repositories
env APT_CONFIG="$MMDEBSTRAP_APT_CONFIG" apt-get indextargets --no-release-info --format '$(REPO_URI)' \
	| sed -ne 's/^file:\/\+//p' \
	| sort -u \
	| while IFS= read -r raw_path; do
		if ! path="$(safe_repo_path "$raw_path")"; then
			echo "W: refusing unsafe file repository path: $raw_path" >&2
			continue
		fi
		if ! resolve_contained_target "/$path" "/$path"; then
			echo "W: refusing file repository outside generated root: /$path" >&2
			continue
		fi
		if [ ! -d "$canonical_source" ]; then
			echo "W: $canonical_source is not an existing directory" >&2
			continue
		fi
		case $MMDEBSTRAP_MODE in
			root|unshare)
				echo "bind-mounting $canonical_source into the chroot" >&2
				mkdir -p "$canonical_target"
				mount -o ro,bind "$canonical_source" "$canonical_target"
				;;
			*)
				echo "copying $canonical_source into the chroot" >&2
				mkdir -p "$canonical_target"
				"$MMDEBSTRAP_ARGV0" --hook-helper "$rootdir" "$MMDEBSTRAP_MODE" "$MMDEBSTRAP_HOOK" env "$MMDEBSTRAP_VERBOSITY" sync-in "$canonical_source" "/$target_relative" <&"$MMDEBSTRAP_HOOKSOCK" >&"$MMDEBSTRAP_HOOKSOCK"
				;;
		esac
		record_target
	done

# process all files given via --include
set -f # turn off pathname expansion
IFS=',' # split by comma
for pkg in $MMDEBSTRAP_INCLUDE; do
	set +f; unset IFS
	case $pkg in
		./*|../*|/*) : ;; # we are interested in this case
		*) continue ;; # not a file
	esac
	# undo escaping
	pkg="$(printf '%s' "$pkg" | sed 's/%2C/,/g; s/%25/%/g')"
	if [ ! -f "$pkg" ]; then
		echo "$pkg does not exist" >&2
		continue
	fi
	if ! resolve_contained_target "$pkg"; then
		echo "W: refusing package file outside generated root: $pkg" >&2
		continue
	fi
	mkdir -p "$(dirname "$canonical_target")"
	case $MMDEBSTRAP_MODE in
		root|unshare)
			echo "bind-mounting $canonical_source into the chroot" >&2
			touch "$canonical_target"
			mount -o bind "$canonical_source" "$canonical_target"
			;;
		*)
			echo "copying $canonical_source into the chroot" >&2
			"$MMDEBSTRAP_ARGV0" --hook-helper "$rootdir" "$MMDEBSTRAP_MODE" "$MMDEBSTRAP_HOOK" env "$MMDEBSTRAP_VERBOSITY" upload "$canonical_source" "/$target_relative" <&"$MMDEBSTRAP_HOOKSOCK" >&"$MMDEBSTRAP_HOOKSOCK"
			;;
	esac
	record_target
done
set +f; unset IFS
