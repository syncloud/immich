#!/bin/sh -ex

DIR=$( cd "$( dirname "$0" )" && pwd )
cd ${DIR}

BUILD_DIR=${DIR}/../build/snap/redis

rm -rf ${BUILD_DIR}
mkdir -p ${BUILD_DIR}

cp -r /usr ${BUILD_DIR}
ln -s usr/lib ${BUILD_DIR}/lib

rm -rf ${BUILD_DIR}/usr/share/doc
rm -rf ${BUILD_DIR}/usr/share/man

mkdir ${BUILD_DIR}/bin
cp ${DIR}/bin/* ${BUILD_DIR}/bin

du -sh ${BUILD_DIR}
