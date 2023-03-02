#!/bin/sh

set -eu

# This script fills either cache.A or cache.B with new content and then
# atomically switches the cache symlink from one to the other at the end.
# This way, at no point will the cache be in an non-working state, even
# when this script got canceled at any point.
# Working with two directories also automatically prunes old packages in
# the local repository.

deletecache() {
	dir="$1"
	echo "running deletecache $dir">&2
	if [ ! -e "$dir" ]; then
		return
	fi
	if [ ! -e "$dir/mmdebstrapcache" ]; then
		echo "$dir cannot be the mmdebstrap cache" >&2
		return 1
	fi
	# be very careful with removing the old directory
	for dist in oldstable stable testing unstable; do
		for variant in minbase buildd -; do
			if [ -e "$dir/debian-$dist-$variant.tar" ]; then
				rm "$dir/debian-$dist-$variant.tar"
			else
				echo "does not exist: $dir/debian-$dist-$variant.tar" >&2
			fi
		done
		if [ -e "$dir/debian/dists/$dist" ]; then
			rm --one-file-system --recursive "$dir/debian/dists/$dist"
		else
			echo "does not exist: $dir/debian/dists/$dist" >&2
		fi
		case "$dist" in oldstable|stable)
			if [ -e "$dir/debian/dists/$dist-updates" ]; then
				rm --one-file-system --recursive "$dir/debian/dists/$dist-updates"
			else
				echo "does not exist: $dir/debian/dists/$dist-updates" >&2
			fi
			;;
		esac
		case "$dist" in
			oldstable)
				if [ -e "$dir/debian-security/dists/$dist/updates" ]; then
					rm --one-file-system --recursive "$dir/debian-security/dists/$dist/updates"
				else
					echo "does not exist: $dir/debian-security/dists/$dist/updates" >&2
				fi
				;;
			stable)
				if [ -e "$dir/debian-security/dists/$dist-security" ]; then
					rm --one-file-system --recursive "$dir/debian-security/dists/$dist-security"
				else
					echo "does not exist: $dir/debian-security/dists/$dist-security" >&2
				fi
				;;
		esac
	done
	for f in "$dir/debian-"*.qcow; do
		if [ -e "$f" ]; then
			rm --one-file-system "$f"
		fi
	done
	if [ -e "$dir/debian/pool/main" ]; then
		rm --one-file-system --recursive "$dir/debian/pool/main"
	else
		echo "does not exist: $dir/debian/pool/main" >&2
	fi
	if [ -e "$dir/debian-security/pool/updates/main" ]; then
		rm --one-file-system --recursive "$dir/debian-security/pool/updates/main"
	else
		echo "does not exist: $dir/debian-security/pool/updates/main" >&2
	fi
	for i in $(seq 1 6); do
		if [ ! -e "$dir/debian$i" ]; then
			continue
		fi
		rm "$dir/debian$i"
	done
	rm "$dir/mmdebstrapcache"
	# remove all symlinks
	find "$dir" -type l -delete

	# now the rest should only be empty directories
	if [ -e "$dir" ]; then
		find "$dir" -depth -print0 | xargs -0 --no-run-if-empty rmdir
	else
		echo "does not exist: $dir" >&2
	fi
}

cleanup_newcachedir() {
	kill "$PROXYPID" || :
	echo "running cleanup_newcachedir"
	deletecache "$newcachedir"
}

cleanupapt() {
	echo "running cleanupapt" >&2
	if [ ! -e "$rootdir" ]; then
		return
	fi
	for f in \
		"$rootdir/var/cache/apt/archives/"*.deb \
		"$rootdir/var/cache/apt/archives/partial/"*.deb \
		"$rootdir/var/cache/apt/"*.bin \
		"$rootdir/var/lib/apt/lists/"* \
		"$rootdir/var/lib/dpkg/status" \
		"$rootdir/var/lib/dpkg/lock-frontend" \
		"$rootdir/var/lib/dpkg/lock" \
		"$rootdir/var/lib/apt/lists/lock" \
		"$rootdir/etc/apt/apt.conf" \
		"$rootdir/etc/apt/sources.list.d/"* \
		"$rootdir/etc/apt/preferences.d/"* \
		"$rootdir/etc/apt/sources.list" \
		"$rootdir/var/cache/apt/archives/lock"; do
		if [ ! -e "$f" ]; then
			echo "does not exist: $f" >&2
			continue
		fi
		if [ -d "$f" ]; then
			rmdir "$f"
		else
			rm "$f"
		fi
	done
	find "$rootdir" -depth -print0 | xargs -0 --no-run-if-empty rmdir
}

# note: this function uses brackets instead of curly braces, so that it's run
# in its own process and we can handle traps independent from the outside
update_cache() (
	dist="$1"
	nativearch="$2"

	# use a subdirectory of $newcachedir so that we can use
	# hardlinks
	rootdir="$newcachedir/apt"
	mkdir -p "$rootdir"

	# we only set this trap here and overwrite the previous trap, because
	# the update_cache function is run as part of a pipe and thus in its
	# own process which will EXIT after it finished
	trap "cleanupapt" EXIT INT TERM

	for p in /etc/apt/apt.conf.d /etc/apt/sources.list.d /etc/apt/preferences.d /var/cache/apt/archives /var/lib/apt/lists/partial /var/lib/dpkg; do
		mkdir -p "$rootdir/$p"
	done

	# read sources.list content from stdin
	cat > "$rootdir/etc/apt/sources.list"

	cat << END > "$rootdir/etc/apt/apt.conf"
Apt::Architecture "$nativearch";
Apt::Architectures "$nativearch";
Dir::Etc "$rootdir/etc/apt";
Dir::State "$rootdir/var/lib/apt";
Dir::Cache "$rootdir/var/cache/apt";
Apt::Install-Recommends false;
Apt::Get::Download-Only true;
Acquire::Languages "none";
Dir::Etc::Trusted "/etc/apt/trusted.gpg";
Dir::Etc::TrustedParts "/etc/apt/trusted.gpg.d";
Acquire::http::Proxy "http://127.0.0.1:8080/";
END

	: > "$rootdir/var/lib/dpkg/status"

	if [ "$dist" = "$DEFAULT_DIST" ] && [ "$nativearch" = "$HOSTARCH" ] && [ "$USE_HOST_APT_CONFIG" = "yes" ]; then
		# we append sources and settings instead of overwriting after
		# an empty line
		for f in /etc/apt/sources.list /etc/apt/sources.list.d/*; do
			[ -e "$f" ] || continue
			[ -e "$rootdir/$f" ] && echo >> "$rootdir/$f"
			# we do not add entries from deb.debian.org or
			# otherwise tests will fail if mirror pushes happen
			# while the script is running
			grep -v deb.debian.org/debian "$f" >> "$rootdir/$f" || :
		done
		for f in /etc/apt/preferences.d/*; do
			[ -e "$f" ] || continue
			[ -e "$rootdir/$f" ] && echo >> "$rootdir/$f"
			cat "$f" >> "$rootdir/$f"
		done
	fi

	APT_CONFIG="$rootdir/etc/apt/apt.conf" apt-get update

	pkgs=$(APT_CONFIG="$rootdir/etc/apt/apt.conf" apt-get indextargets \
		--format '$(FILENAME)' 'Created-By: Packages' "Architecture: $nativearch" \
		| xargs --delimiter='\n' /usr/lib/apt/apt-helper cat-file \
		| grep-dctrl --no-field-names --show-field=Package --exact-match \
			\( --field=Essential yes --or --field=Priority required \
			--or --field=Priority important --or --field=Priority standard \
			\))

	pkgs="$pkgs build-essential busybox gpg eatmydata fakechroot fakeroot"

	# we need usr-is-merged to simulate debootstrap behaviour for all dists
	# starting from Debian 12 (Bullseye)
	case "$dist" in
		oldstable|stable) : ;;
		*) pkgs="$pkgs usr-is-merged usrmerge" ;;
	esac

	# shellcheck disable=SC2086
	APT_CONFIG="$rootdir/etc/apt/apt.conf" apt-get --yes install $pkgs

	rm "$rootdir/var/cache/apt/archives/lock"
	rmdir "$rootdir/var/cache/apt/archives/partial"
	APT_CONFIG="$rootdir/etc/apt/apt.conf" apt-get --option Dir::Etc::SourceList=/dev/null update
	APT_CONFIG="$rootdir/etc/apt/apt.conf" apt-get clean

	cleanupapt

	# this function is run in its own process, so we unset all traps before
	# returning
	trap "-" EXIT INT TERM
)

if [ -e "./shared/cache.A" ] && [ -e "./shared/cache.B" ]; then
	echo "both ./shared/cache.A and ./shared/cache.B exist" >&2
	echo "was a former run of the script aborted?" >&2
	if [ -e ./shared/cache ]; then
		echo "cache symlink points to $(readlink ./shared/cache)" >&2
		case "$(readlink ./shared/cache)" in
			cache.A)
				echo "removing ./shared/cache.B" >&2
				rm -r ./shared/cache.B
				;;
			cache.B)
				echo "removing ./shared/cache.A" >&2
				rm -r ./shared/cache.A
				;;
			*)
				echo "unexpected" >&2
				exit 1
				;;
		esac
	else
		echo "./shared/cache doesn't exist" >&2
		exit 1
	fi
fi

if [ -e "./shared/cache.A" ]; then
	oldcache=cache.A
	newcache=cache.B
else
	oldcache=cache.B
	newcache=cache.A
fi

oldcachedir="./shared/$oldcache"
newcachedir="./shared/$newcache"

oldmirrordir="$oldcachedir/debian"
newmirrordir="$newcachedir/debian"

mirror="http://deb.debian.org/debian"
security_mirror="http://security.debian.org/debian-security"
components=main

: "${DEFAULT_DIST:=unstable}"
: "${ONLY_DEFAULT_DIST:=no}"
: "${ONLY_HOSTARCH:=no}"
: "${HAVE_QEMU:=yes}"
: "${RUN_MA_SAME_TESTS:=yes}"
# by default, use the mmdebstrap executable in the current directory
: "${CMD:=./mmdebstrap}"
: "${USE_HOST_APT_CONFIG:=no}"

if [ -e "$oldmirrordir/dists/$DEFAULT_DIST/InRelease" ]; then
	http_code=$(curl --output /dev/null --silent --location --head --time-cond "$oldmirrordir/dists/$DEFAULT_DIST/InRelease" --write-out '%{http_code}' "$mirror/dists/$DEFAULT_DIST/InRelease")
	case "$http_code" in
		200) ;; # need update
		304) echo up-to-date; exit 0;;
		*) echo "unexpected status: $http_code"; exit 1;;
	esac
fi

./caching_proxy.py "$oldcachedir" "$newcachedir" &
PROXYPID=$!

for i in $(seq 10); do
	curl --proxy "http://127.0.0.1:8080/" --silent -o /dev/null "http://deb.debian.org/debian/dists/$DEFAULT_DIST/InRelease" && break
	sleep 1
done
if [ ! -s "$newmirrordir/dists/$DEFAULT_DIST/InRelease" ]; then
	echo "failed to start proxy" >&2
	kill $PROXYPID
	exit 1
fi

trap "cleanup_newcachedir" EXIT INT TERM

mkdir -p "$newcachedir"
touch "$newcachedir/mmdebstrapcache"

HOSTARCH=$(dpkg --print-architecture)
arches="$HOSTARCH"
if [ "$HOSTARCH" = amd64 ]; then
	arches="$arches arm64 i386"
elif [ "$HOSTARCH" = arm64 ]; then
	arches="$arches amd64 armhf"
fi

# we need the split_inline_sig() function
# shellcheck disable=SC1091
. /usr/share/debootstrap/functions

for dist in oldstable stable testing unstable; do
	for nativearch in $arches; do
		# non-host architectures are only downloaded for $DEFAULT_DIST
		if [ "$nativearch" != "$HOSTARCH" ] && [ "$DEFAULT_DIST" != "$dist" ]; then
			continue
		fi
		# if ONLY_DEFAULT_DIST is set, only download DEFAULT_DIST
		if [ "$ONLY_DEFAULT_DIST" = "yes" ] && [ "$DEFAULT_DIST" != "$dist" ]; then
			continue
		fi
		if [ "$ONLY_HOSTARCH" = "yes" ] && [ "$nativearch" != "$HOSTARCH" ]; then
			continue
		fi
		# we need a first pass without updates and security patches
		# because otherwise, old package versions needed by
		# debootstrap will not get included
		echo "deb [arch=$nativearch] $mirror $dist $components" | update_cache "$dist" "$nativearch"
		# we need to include the base mirror again or otherwise
		# packages like build-essential will be missing
		case "$dist" in
			oldstable)
				cat << END | update_cache "$dist" "$nativearch"
deb [arch=$nativearch] $mirror $dist $components
deb [arch=$nativearch] $mirror $dist-updates main
deb [arch=$nativearch] $security_mirror $dist/updates main
END
				;;
			stable)
				cat << END | update_cache "$dist" "$nativearch"
deb [arch=$nativearch] $mirror $dist $components
deb [arch=$nativearch] $mirror $dist-updates main
deb [arch=$nativearch] $security_mirror $dist-security main
END
				;;
		esac
	done
	codename=$(awk '/^Codename: / { print $2; }' < "$newmirrordir/dists/$dist/InRelease")
	ln -s "$dist" "$newmirrordir/dists/$codename"

	# split the InRelease file into Release and Release.gpg not because apt
	# or debootstrap need it that way but because grep-dctrl does
	split_inline_sig \
		"$newmirrordir/dists/$dist/InRelease" \
		"$newmirrordir/dists/$dist/Release" \
		"$newmirrordir/dists/$dist/Release.gpg"
	touch --reference="$newmirrordir/dists/$dist/InRelease" "$newmirrordir/dists/$dist/Release" "$newmirrordir/dists/$dist/Release.gpg"
done

kill $PROXYPID

# Create some symlinks so that we can trick apt into accepting multiple apt
# lines that point to the same repository but look different. This is to
# avoid the warning:
# W: Target Packages (main/binary-all/Packages) is configured multiple times...
for i in $(seq 1 6); do
	ln -s debian "$newcachedir/debian$i"
done

tmpdir=""

cleanuptmpdir() {
	if [ -z "$tmpdir" ]; then
		return
	fi
	if [ ! -e "$tmpdir" ]; then
		return
	fi
	for f in "$tmpdir/worker.sh" \
		"$tmpdir/mini-httpd" "$tmpdir/hosts" \
		"$tmpdir/debian-chroot.tar" \
		"$tmpdir/mmdebstrap.service"; do
		if [ ! -e "$f" ]; then
			echo "does not exist: $f" >&2
			continue
		fi
		rm "$f"
	done
	rmdir "$tmpdir"
}

SOURCE_DATE_EPOCH="$(date --date="$(grep-dctrl -s Date -n '' "$newmirrordir/dists/$DEFAULT_DIST/Release")" +%s)"
export SOURCE_DATE_EPOCH

if [ "$HAVE_QEMU" = "yes" ]; then
	case "$HOSTARCH" in
		amd64|i386|arm64)
			# okay
			;;
		*)
			echo "qemu support is only available on amd64, i386 and arm64" >&2
			echo "because grub is only available on those arches" >&2
			exit 1
			;;
	esac

	# we use the caching proxy again when building the qemu image
	#  - we can re-use the packages that were already downloaded earlier
	#  - we make sure that the qemu image uses the same Release file even
	#    if a mirror push happened between now and earlier
	#  - we avoid polluting the mirror with the additional packages by
	#    using --readonly
	./caching_proxy.py --readonly "$oldcachedir" "$newcachedir" &
	PROXYPID=$!

	for i in $(seq 10); do
		curl --proxy "http://127.0.0.1:8080/" --silent -o /dev/null "http://deb.debian.org/debian/dists/$DEFAULT_DIST/InRelease" && break
		sleep 1
	done
	if [ ! -s "$newmirrordir/dists/$DEFAULT_DIST/InRelease" ]; then
		echo "failed to start proxy" >&2
		kill $PROXYPID
		exit 1
	fi

	# We must not use any --dpkgopt here because any dpkg options still
	# leak into the chroot with chrootless mode.
	# We do not use our own package cache here because
	#   - it doesn't (and shouldn't) contain the extra packages
	#   - it doesn't matter if the base system is from a different mirror timestamp
	# procps is needed for /sbin/sysctl
	tmpdir="$(mktemp -d)"
	trap "cleanuptmpdir; cleanup_newcachedir" EXIT INT TERM

	pkgs=perl-doc,systemd-sysv,perl,arch-test,fakechroot,fakeroot,mount,uidmap,qemu-user-static,binfmt-support,qemu-user,dpkg-dev,mini-httpd,libdevel-cover-perl,libtemplate-perl,debootstrap,procps,apt-cudf,aspcud,python3,libcap2-bin,gpg,debootstrap,distro-info-data,iproute2,ubuntu-keyring,apt-utils,grub-efi
	if [ "$DEFAULT_DIST" != "oldstable" ]; then
		pkgs="$pkgs,squashfs-tools-ng,genext2fs"
	fi
	if [ ! -e ./mmdebstrap ]; then
		pkgs="$pkgs,mmdebstrap"
	fi
	case "$HOSTARCH" in
		amd64|arm64)
			pkgs="$pkgs,linux-image-$HOSTARCH"
			;;
		i386)
			pkgs="$pkgs,linux-image-686"
			;;
		ppc64el)
			pkgs="$pkgs,linux-image-powerpc64le"
			;;
		*)
			echo "no kernel image for $HOSTARCH" >&2
			exit 1
			;;
	esac
	if [ "$HOSTARCH" = amd64 ] && [ "$RUN_MA_SAME_TESTS" = "yes" ]; then
		arches=amd64,arm64
		pkgs="$pkgs,libfakechroot:arm64,libfakeroot:arm64"
	elif [ "$HOSTARCH" = arm64 ] && [ "$RUN_MA_SAME_TESTS" = "yes" ]; then
		arches=arm64,amd64
		pkgs="$pkgs,libfakechroot:amd64,libfakeroot:amd64"
	else
		arches=$HOSTARCH
	fi
	$CMD --variant=apt --architectures="$arches" --include="$pkgs" \
		--setup-hook='echo "Acquire::http::Proxy \"http://127.0.0.1:8080/\";" > "$1/etc/apt/apt.conf.d/00proxy"' \
		--customize-hook='rm "$1/etc/apt/apt.conf.d/00proxy"' \
		"$DEFAULT_DIST" - "$mirror" > "$tmpdir/debian-chroot.tar"

	kill $PROXYPID

	cat << END > "$tmpdir/mmdebstrap.service"
[Unit]
Description=mmdebstrap worker script

[Service]
Type=oneshot
ExecStart=/worker.sh

[Install]
WantedBy=multi-user.target
END
	# here is something crazy:
	# as we run mmdebstrap, the process ends up being run by different users with
	# different privileges (real or fake). But for being able to collect
	# Devel::Cover data, they must all share a single directory. The only way that
	# I found to make this work is to mount the database directory with a
	# filesystem that doesn't support ownership information at all and a umask that
	# gives read/write access to everybody.
	# https://github.com/pjcj/Devel--Cover/issues/223
	cat << 'END' > "$tmpdir/worker.sh"
#!/bin/sh
echo 'root:root' | chpasswd
mount -t 9p -o trans=virtio,access=any,msize=128k mmdebstrap /mnt
# need to restart mini-httpd because we mounted different content into www-root
systemctl restart mini-httpd

handler () {
	while IFS= read -r line || [ -n "$line" ]; do
		printf "%s %s: %s\n" "$(date -u -d "0 $(date +%s.%3N) seconds - $2 seconds" +"%T.%3N")" "$1" "$line"
	done
}

(
	cd /mnt;
	if [ -e cover_db.img ]; then
		mkdir -p cover_db
		mount -o loop,umask=000 cover_db.img cover_db
	fi

	now=$(date +%s.%3N)
	ret=0
	{ { { { {
	          sh -x ./test.sh 2>&1 1>&4 3>&- 4>&-; echo $? >&2;
	        } | handler E "$now" >&3;
	      } 4>&1 | handler O "$now" >&3;
	    } 2>&1;
	  } | { read xs; exit $xs; };
	} 3>&1 || ret=$?
	echo $ret > /mnt/exitstatus.txt
	if [ -e cover_db.img ]; then
		df -h cover_db
		umount cover_db
	fi
) > /mnt/output.txt 2>&1
umount /mnt
systemctl poweroff
END
	chmod +x "$tmpdir/worker.sh"
	# initially we serve from the new cache so that debootstrap can grab
	# the new package repository and not the old
	cat << END > "$tmpdir/mini-httpd"
START=1
DAEMON_OPTS="-h 127.0.0.1 -p 80 -u nobody -dd /mnt/$newcache -i /var/run/mini-httpd.pid -T UTF-8"
END
	cat << 'END' > "$tmpdir/hosts"
127.0.0.1 localhost
END
	#libguestfs-test-tool
	#export LIBGUESTFS_DEBUG=1 LIBGUESTFS_TRACE=1
	#
	# In case the rootfs was prepared in fakechroot mode, ldconfig has to
	# run to populate /etc/ld.so.cache or otherwise fakechroot tests will
	# fail to run.
	#
	# The disk size is sufficient in most cases. Sometimes, gcc will do
	# an upload with unstripped executables to make tracking down ICEs much
	# easier (see #872672, #894014). During times with unstripped gcc, the
	# buildd variant will not be 400MB but 1.3GB large and needs a 10G
	# disk.
	if [ -z ${DISK_SIZE+x} ]; then
		DISK_SIZE=10G
	fi
	case "$HOSTARCH" in
		amd64) GRUB_TARGET=x86_64-efi;;
		i386) GRUB_TARGET=i386-efi;;
		arm64) GRUB_TARGET=arm64-efi;;
	esac
	case "$HOSTARCH" in
		arm64) SERIAL="loglevel=3 console=tty0 console=ttyAMA0,115200n8" ;;
		*) SERIAL="loglevel=3 console=tty0 console=ttyS0,115200n8" ;;
	esac
	guestfish -- \
		disk-create "$newcachedir/debian-$DEFAULT_DIST.qcow" qcow2 "$DISK_SIZE" : \
		add-drive "$newcachedir/debian-$DEFAULT_DIST.qcow" format:qcow2 : \
		launch : \
		part-init /dev/sda gpt : \
		part-add /dev/sda primary 8192 262144 : \
		part-add /dev/sda primary 262145 -34 : \
		part-set-gpt-type /dev/sda 1 C12A7328-F81F-11D2-BA4B-00A0C93EC93B  : \
		mkfs ext2 /dev/sda2 : \
		mount /dev/sda2 / : \
		tar-in "$tmpdir/debian-chroot.tar" / xattrs:true : \
		mkdir-p /boot/efi : \
		mkfs vfat /dev/sda1 : \
		mount /dev/sda1 /boot/efi : \
		command /sbin/ldconfig : \
		mkdir-p /etc/systemd/system/multi-user.target.wants : \
		ln-s ../mmdebstrap.service /etc/systemd/system/multi-user.target.wants/mmdebstrap.service : \
		copy-in "$tmpdir/mmdebstrap.service" /etc/systemd/system/ : \
		copy-in "$tmpdir/worker.sh" / : \
		copy-in "$tmpdir/mini-httpd" /etc/default : \
		copy-in "$tmpdir/hosts" /etc/ : \
		touch /mmdebstrap-testenv : \
		command "sh -c 'echo UUID=\$(blkid -c /dev/null -o value -s UUID /dev/sda2) / ext4 errors=remount-ro 0 1 > /etc/fstab'" : \
		command "sh -c 'echo UUID=\$(blkid -c /dev/null -o value -s UUID /dev/sda1) /boot/efi vfat errors=remount-ro 0 2 >> /etc/fstab'" : \
		command "sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=/GRUB_CMDLINE_LINUX_DEFAULT=\"biosdevname=0 net.ifnames=0 consoleblank=0 rw $SERIAL\"/' /etc/default/grub" : \
		command "update-initramfs -u" : \
		command "grub-mkconfig -o /boot/grub/grub.cfg" : \
		command "grub-install /dev/sda --target=$GRUB_TARGET --no-nvram --force-extra-removable --no-floppy --modules=part_gpt --grub-mkdevicemap=/boot/grub/device.map" : \
		sync : \
		umount /boot/efi : \
		umount / : \
		shutdown
	cleanuptmpdir
	trap "cleanup_newcachedir" EXIT INT TERM
fi

if [ "$HAVE_QEMU" = "yes" ]; then
	# now replace the minihttpd config with one that serves the new repository
	guestfish -a "$newcachedir/debian-$DEFAULT_DIST.qcow" -i <<EOF
upload -<<END /etc/default/mini-httpd
START=1
DAEMON_OPTS="-h 127.0.0.1 -p 80 -u nobody -dd /mnt/cache -i /var/run/mini-httpd.pid -T UTF-8"
END
EOF
fi

# delete possibly leftover symlink
if [ -e ./shared/cache.tmp ]; then
	rm ./shared/cache.tmp
fi
# now atomically switch the symlink to point to the other directory
ln -s $newcache ./shared/cache.tmp
mv --no-target-directory ./shared/cache.tmp ./shared/cache

deletecache "$oldcachedir"

trap - EXIT INT TERM
