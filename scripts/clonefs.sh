#!/bin/sh
#
# Copyright (c) 2009-2014, GhostBSD Project All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistribution's of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
#
# 2. Redistribution's in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# $Id: clonefs.sh,v 1.13 Saturday, June 20 2015 Ovidiu Angelescu $

set -e -u

if [ -z "${LOGFILE:-}" ]; then
    echo "This script can't run standalone."
    echo "Please use launch.sh to execute it."
    exit 1
fi

DEVICE=`cat ${CDDIR}/mddevice`

make_manifest()
{
echo "### Make iso manifest."
echo "### Make iso manifest." >> ${LOGFILE} 2>&1
cat > ${BASEDIR}/mnt/manifest.sh << "EOF"
#!/bin/sh 
# builds iso manifest
cd /mnt
pkg info > manifest
rm manifest.sh
EOF

chrootcmd="chroot ${BASEDIR} sh /mnt/manifest.sh"
$chrootcmd

if [ ! -d /usr/obj/${ARCH}/${PACK_PROFILE} ]; then
    mkdir -p /usr/obj/${ARCH}/${PACK_PROFILE}
fi
mv -f ${BASEDIR}/mnt/manifest /usr/obj/${ARCH}/${PACK_PROFILE}/$(echo ${ISOPATH} | cut -d / -f6).manifest
}

uniondirs_prepare()
{
echo "#### Building bootable ISO image for ${ARCH} ####"
# Creates etc/fstab to avoid messages about missing it
if [ ! -e ${BASEDIR}/etc/fstab ] ; then
    touch ${BASEDIR}/etc/fstab
fi

echo "### Prepare for compression build environment"
echo "### Prepare for compression build environment" >> ${LOGFILE} 2>&1
# clean packages cache, tmp and var/log 
rm -f  ${BASEDIR}/var/cache/pkg/*
rm -Rf ${BASEDIR}/tmp/*
rm -Rf ${BASEDIR}/var/log/*
# makes usr/src/sys dir because of cosmetical reason
mkdir -p ${BASEDIR}/usr/src/sys
# removes dist dir
rm -R ${BASEDIR}/dist
}

compress_fs()
{
echo "### Compressing filesystem using $MD_BACKEND"
echo "### Compressing filesystem using $MD_BACKEND" >> ${LOGFILE} 2>&1
if [ "${MD_BACKEND}" = "file" ] ; then
  mkuzip -v -o ${CDDIR}/data/sysroot.uzip -s 65536 ${CDDIR}/data/sysroot.ufs >> ${LOGFILE} 2>&1
  rm -f ${CDDIR}/data/sysroot.ufs
else
  mkuzip -v -o ${BASEDIR}/data/sysroot.uzip  -s 65536 /dev/${DEVICE} >> ${LOGFILE} 2>&1
fi
}

boot()
{
    cd "${BASEDIR}"
    tar -cf - --exclude boot/kernel boot | tar -xf - -C "${CDDIR}"
    for kfile in kernel geom_uzip.ko nullfs.ko tmpfs.ko unionfs.ko; do
        tar -cf - boot/kernel/${kfile} | tar -xf - -C "${CDDIR}"
    done
    cd "${LOCALDIR}/scripts"
    install -o root -g wheel -m 644 "loader.conf" "${CDDIR}/boot/"
}

mount_ufs()
{
DIRSIZE=$(($(du -kd 0 ${BASEDIR}/usr | cut -f 1)))
echo "${PACK_PROFILE}${ARCH}_${BDATE}_mdsize=$(($DIRSIZE + ($DIRSIZE/10)))" > ${CDDIR}/data/mdsize
boot
uniondirs_prepare

MOUNTPOINT=${BASEDIR}
umount -f ${MOUNTPOINT}

if [ "${MD_BACKEND}" = "file" ] 
    then
        mdconfig -d -u ${DEVICE}
        compress_fs
    else
        compress_fs
        mdconfig -d -u ${DEVICE}
fi
rm -f ${CDDIR}/mddevice
echo "### Done filesystem compress"
echo "### Done filesystem compress" >> ${LOGFILE} 2>&1
}

make_mtree()
{
echo "Saving mtree structure..."
echo "Saving mtree structure..." >> ${LOGFILE} 2>&1
mtree -Pcp ${BASEDIR}/usr/home  > ${BASEDIR}/dist/home.dist
}


make_manifest
mount_ufs

set -e
cd ${LOCALDIR}
