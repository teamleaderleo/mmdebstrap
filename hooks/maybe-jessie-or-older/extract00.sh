#!/bin/sh

set -eu

# if dpkg is new enough, do nothing
# we cannot ask dpkg-query about the version because dpkg is only extracted
# but not installed at this point
dpkg_ver="$(chroot "$1" dpkg --version | grep --extended-regexp --only-matching '[0-9]+\.[0-9.]+')"
if dpkg --compare-versions "$dpkg_ver" ge 1.17.11; then
	echo "dpkg version $dpkg_ver is >= 1.17.11 -- not running jessie-or-older extract00 hook" >&2
	exit 0
else
	echo "dpkg version $dpkg_ver is << 1.17.11 -- running jessie-or-older extract00 hook" >&2
fi

# resolve the script path using several methods in order:
#  1. using dirname -- "$0"
#  2. using ./hooks
#  3. using /usr/share/mmdebstrap/hooks/
for p in "$(dirname -- "$0")/.." ./hooks /usr/share/mmdebstrap/hooks; do
	if [ -x "$p/jessie-or-older/extract00.sh" ] && [ -x "$p/jessie-or-older/extract01.sh" ]; then
		"$p/jessie-or-older/extract00.sh" "$1"
		exit 0
	fi
done

echo "cannot find jessie-or-older hook anywhere" >&2
exit 1
