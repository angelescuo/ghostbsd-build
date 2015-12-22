#!/bin/sh

PATH="/rescue"

if [ "`ps -o command 1 | tail -n 1 | ( read c o; echo ${o} )`" = "-s" ]; then
	echo "==> Running in single-user mode"
	SINGLE_USER="true"
fi

echo "==> Remount rootfs as read-write"
mount -u -w /

echo "==> Mount cdrom"
mount_cd9660 /dev/iso9660/GHOSTBSD /cdrom
mdmfs -P -F /cdrom/data/sysroot.uzip -o ro md.uzip /sysroot


if [ "$SINGLE_USER" = "true" ]; then
    echo -n "Enter memdisk size in MB used for read-write access in the live system: "
    read MEMDISK_SIZE
    mdmfs -s "${MEMDISK_SIZE}m" md /union || exit 1
else
    MEMDISK_SIZE="$(($(sysctl -n hw.usermem) / 2097152))"
    mdmfs -s "${MEMDISK_SIZE}m" md /union || exit 1

fi

echo "==> Prepare union filesystem"
mount -t unionfs /union /sysroot

mkdir -p /sysroot/mnt/cdrom
mount_nullfs -o ro /cdrom /sysroot/mnt/cdrom

echo "==> Mount devfs"
mount -t devfs devfs /sysroot/dev

if [ "$SINGLE_USER" = "true" ]; then
	echo "Starting interactive shell in temporary rootfs ..."
	sh
fi

kenv init_shell="/bin/sh"
exit 0
