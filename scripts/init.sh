#!/bin/sh

PATH="/rescue"

if [ "`ps -o command 1 | tail -n 1 | ( read c o; echo ${o} )`" = "-s" ]; then
	echo "==> Running in single-user mode"
	SINGLE_USER="true"
fi


echo "==> Mount compressed filesystem"
DEVICE=$(mdconfig -a -t vnode -o readonly -f /data/sysroot.uzip)
mount  -r /dev/${DEVICE}.uzip /sysroot 


if [ "$SINGLE_USER" = "true" ]; then
    echo -n "Enter memdisk size in MB used for read-write access in the live system: "
    read MEMDISK_SIZE
    device=$(mdconfig -a -t malloc -s ${MEMDISK_SIZE}m)
else
    MEMDISK_SIZE="$(($(sysctl -n hw.usermem) / 2))b"
    device=$(mdconfig -a -t malloc -s ${MEMDISK_SIZE})
fi

echo "==> Prepare union filesystem"
newfs /dev/${device} > /dev/null 2>&1
mount /dev/${device} /union
mount_unionfs -o noatime -o copymode=transparent /union /sysroot


echo "==> Mount devfs"
mount -t devfs devfs /sysroot/dev

if [ "$SINGLE_USER" = "true" ]; then
	echo "Starting interactive shell in temporary rootfs ..."
	sh
fi

kenv init_shell="/bin/sh"
exit 0
