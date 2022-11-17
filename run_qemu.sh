#!/bin/sh

set -eu

: "${DEFAULT_DIST:=unstable}"
: "${cachedir:=./shared/cache}"
tmpdir="$(mktemp -d)"

cleanup() {
	rv=$?
	rm -f "$tmpdir/debian-$DEFAULT_DIST-overlay.qcow"
	rm -f "$tmpdir/log"
	[ -e "$tmpdir" ] && rmdir "$tmpdir"
	if [ -e shared/result.txt ]; then
		head --lines=-1 shared/result.txt
		res="$(tail --lines=1 shared/result.txt)"
		rm shared/result.txt
		if [ "$res" != "0" ]; then
			# this might possibly overwrite another non-zero rv
			rv=1
		fi
	fi
	exit $rv
}

trap cleanup INT TERM EXIT

ARCH=$(dpkg --print-architecture)
case $ARCH in
	i386)
		MACHINE="accel=kvm:tcg"
		CODE="/usr/share/OVMF/OVMF32_CODE_4M.secboot.fd"
		QEMUARCH="i386"
		;;
	amd64)
		MACHINE="accel=kvm:tcg"
		CODE="/usr/share/OVMF/OVMF_CODE.fd"
		QEMUARCH="x86_64"
		;;
	arm64)
		MACHINE="type=virt,gic-version=host,accel=kvm"
		CODE="/usr/share/AAVMF/AAVMF_CODE.fd"
		QEMUARCH="aarch64"
		;;
	*) echo "qemu kvm not supported on $ARCH" >&2;;
esac

# the path to debian-$DEFAULT_DIST.qcow must be absolute or otherwise qemu will
# look for the path relative to debian-$DEFAULT_DIST-overlay.qcow
qemu-img create -f qcow2 -b "$(realpath $cachedir)/debian-$DEFAULT_DIST.qcow" -F qcow2 "$tmpdir/debian-$DEFAULT_DIST-overlay.qcow"
# to connect to serial use:
#   minicom -D 'unix#/tmp/ttyS0'
#
# or this (quit with ctrl+q):
#   socat stdin,raw,echo=0,escape=0x11 unix-connect:/tmp/ttyS0
ret=0
timeout --foreground 40m qemu-system-"$QEMUARCH" \
	-cpu host \
	-no-user-config \
	-M "$MACHINE" -m 4G -nographic \
	-object rng-random,filename=/dev/urandom,id=rng0 -device virtio-rng-pci,rng=rng0 \
	-monitor unix:/tmp/monitor,server,nowait \
	-serial unix:/tmp/ttyS0,server,nowait \
	-serial unix:/tmp/ttyS1,server,nowait \
	-net nic,model=virtio -net user \
	-drive if=pflash,format=raw,unit=0,read-only=on,file="$CODE" \
	-virtfs local,id=mmdebstrap,path="$(pwd)/shared",security_model=none,mount_tag=mmdebstrap \
	-drive file="$tmpdir/debian-$DEFAULT_DIST-overlay.qcow",cache=unsafe,index=0,if=virtio \
	>"$tmpdir/log" 2>&1 || ret=$?
if [ "$ret" -ne 0 ]; then
	cat "$tmpdir/log"
	exit $ret
fi
