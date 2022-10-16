#!/bin/sh

set -eu

if [ "${MMDEBSTRAP_VERBOSITY:-1}" -ge 3 ]; then
        set -x
fi

TARGET="$1"

APT_CONFIG=$MMDEBSTRAP_APT_CONFIG apt-get --yes install -oDPkg::Chroot-Directory="$TARGET" usr-is-merged

chroot "$TARGET" dpkg-query --showformat '${db:Status-Status}\n' --show usr-is-merged | grep -q '^installed$'
chroot "$TARGET" dpkg-query --showformat '${Source}\n' --show usr-is-merged | grep -q '^usrmerge$'
dpkg --compare-versions "1" "lt" "$(chroot "$TARGET" dpkg-query --showformat '${Version}\n' --show usr-is-merged)"
