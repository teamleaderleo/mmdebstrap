#!/bin/sh

set -eu

SUDO=
while [ "$#" -gt 0 ]; do
	key="$1"
	case "$key" in
		SUDO)
			SUDO=sudo
			;;
		*)
			echo "Unknown argument: $key"
			exit 1
			;;
	esac
	shift
done

# subshell so that we can cd without effecting the rest
(
	set +e
	cd ./shared;
	$SUDO sh -x ./test.sh;
	echo $?;
) 2>&1 | tee shared/output.txt
if [ "$(cat shared/exitstatus.txt)" -ne 0 ]; then
	echo "test.sh failed"
	exit 1
fi
