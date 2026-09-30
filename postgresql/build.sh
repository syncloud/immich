#!/bin/sh -xe

DIR=$( cd "$( dirname "$0" )" && pwd )
cd ${DIR}

BUILD_DIR=${DIR}/../build/snap/postgresql

rm -rf ${BUILD_DIR}
mkdir -p ${BUILD_DIR}

cp -r /usr ${BUILD_DIR}

ln -s usr/lib ${BUILD_DIR}/lib

rm -f ${BUILD_DIR}/usr/lib/postgresql/*/lib/vectors.so
rm -rf ${BUILD_DIR}/usr/lib/postgresql/*/lib/bitcode
rm -rf ${BUILD_DIR}/usr/lib/postgresql/*/lib/pgxs
rm -rf ${BUILD_DIR}/usr/share/doc
rm -rf ${BUILD_DIR}/usr/share/man
rm -rf ${BUILD_DIR}/usr/share/locale
rm -rf ${BUILD_DIR}/usr/share/i18n
rm -rf ${BUILD_DIR}/usr/share/perl
rm -rf ${BUILD_DIR}/usr/include
rm -rf ${BUILD_DIR}/usr/lib/*-linux-gnu/perl
rm -rf ${BUILD_DIR}/usr/lib/*-linux-gnu/perl-base

PGBIN=$(echo ${BUILD_DIR}/usr/lib/postgresql/*/bin)
mv ${PGBIN}/postgres ${PGBIN}/postgres.bin
mv ${PGBIN}/pg_dump ${PGBIN}/pg_dump.bin
mkdir ${BUILD_DIR}/bin
cp ${DIR}/bin/* ${BUILD_DIR}/bin
cp ${DIR}/pgbin/* ${PGBIN}

du -sh ${BUILD_DIR}
