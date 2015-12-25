#!/bin/sh
#
# Copyright (c) 2009 GhostBSD
#
# See COPYING for licence terms.
#
# $GhostBSD$
# $Id: buildworld.sh,v 1.8 Wednesday, December 07 2011 21:09 Eric Exp $

set -e -u

if [ -z "${LOGFILE:-}" ]; then
    echo "This script can't run standalone."
    echo "Please use launch.sh to execute it."
    exit 1
fi
mkdir -p ${CDDIR} ${BASEDIR}

build_world()
{
echo "#### Building world for ${ARCH} architecture ####"

if [ -n "${NO_BUILDWORLD:-}" ]; then
    echo "NO_BUILDWORLD set, skipping build" | tee -a ${LOGFILE}
    return
fi

# Set MAKE_CONF variable if it's not already set.
if [ -z "${MAKE_CONF:-}" ]; then
    if [ -n "${MINIMAL:-}" ]; then
	MAKE_CONF=${LOCALDIR}/conf/make.conf.minimal
    else
	MAKE_CONF=${LOCALDIR}/conf/make.conf
    fi
fi

cd $SRCDIR

unset EXTRA

makeargs="${MAKEOPT:-} ${MAKEJ_WORLD:-} __MAKE_CONF=${MAKE_CONF} TARGET_ARCH=${ARCH} SRCCONF=${SRC_CONF}"
echo $makeargs
sleep 10
(env $MAKE_ENV script -aq $LOGFILE make ${makeargs:-} buildworld || print_error;) | grep '^>>>'
}

fetch_freebsd()
{
cd $CDDIR
echo "#### Fetching world for ${ARCH} architecture ####" | tee -a ${LOGFILE}
if [ "${ARCH}" = "amd64" ]; then
    for files in base lib32 ; do
        fetch ftp://ftp.freebsd.org/pub/FreeBSD/releases/${ARCH}/${FBSDRELEASE}/${files}.txz
    done
else
    for files in base ; do
        fetch ftp://ftp.freebsd.org/pub/FreeBSD/releases/${ARCH}/${FBSDRELEASE}/${files}.txz
    done
fi
}


if [ -n "${FETCH_FREEBSDBASE:-}" ]; then
    fetch_freebsd
else
    build_world
fi

set -e
cd $LOCALDIR
