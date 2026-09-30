#!/bin/sh -ex

DIR=$( cd "$( dirname "$0" )" && pwd )
cd ${DIR}

mkdir -p ${DIR}/../artifact

BUILD_DIR=${DIR}/../build/snap/nginx

rm -rf ${BUILD_DIR}
mkdir -p ${BUILD_DIR}

cp -r /etc ${BUILD_DIR}
cp -r /usr ${BUILD_DIR}
ln -s usr/lib ${BUILD_DIR}/lib

rm -rf ${BUILD_DIR}/usr/share/doc
rm -rf ${BUILD_DIR}/usr/share/man

mkdir -p ${BUILD_DIR}/bin
cp ${DIR}/bin/* ${BUILD_DIR}/bin

du -sh ${BUILD_DIR}
