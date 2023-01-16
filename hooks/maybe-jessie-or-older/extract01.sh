#!/bin/sh

set -eu

# If the init package has not been extracted, then it is not part of the
# Essential:yes set and we do not need this workaround. This holds true for the
# init package version 1.34 and later. Instead of asking apt about the init
# version (which might not be the same version that was picked to be installed)
# we check for the presence of the init package by checking whether
# /usr/share/doc/init/copyright exists.

if [ -e "$1/usr/share/doc/init/copyright" ]; then
	echo "the init package is not Essential:yes -- not running jessie-or-older extract01 hook" >&2
	exit 0
else
	echo "the init package is Essential:yes -- running jessie-or-older extract01 hook" >&2
fi

# resolve the script path using several methods in order:
#  1. using dirname -- "$0"
#  2. using ./hooks
#  3. using /usr/share/mmdebstrap/hooks/
for p in "$(dirname -- "$0")/.." ./hooks /usr/share/mmdebstrap/hooks; do
	if [ -x "$p/jessie-or-older/extract00.sh" ] && [ -x "$p/jessie-or-older/extract01.sh" ]; then
		"$p/jessie-or-older/extract01.sh" "$1"
		exit 0
	fi
done

echo "cannot find jessie-or-older hook anywhere" >&2
exit 1
