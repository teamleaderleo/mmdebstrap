#!/bin/sh

set -exu

rootdir="$1"

# Run busybox using an absolute path so that this script also works in case
# /proc is not mounted. Busybox uses /proc/self/exe to figure out the path
# to its executable.
chroot "$rootdir" /bin/busybox --install -s
