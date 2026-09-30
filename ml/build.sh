#!/bin/bash -ex

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd ${DIR}

BUILD_DIR=${DIR}/../build/snap/ml
rm -rf ${BUILD_DIR}
mkdir -p ${BUILD_DIR}

${DIR}/../ci/apt.sh patchelf patch

cp -r /usr ${BUILD_DIR}
cp -r /opt ${BUILD_DIR}

for PATCH in ${DIR}/patches/*.patch; do
    patch -p1 -F0 --batch --forward -d ${BUILD_DIR} < ${PATCH}
done

ln -s usr/lib ${BUILD_DIR}/lib
ln -s usr/bin ${BUILD_DIR}/bin
ln -s usr/sbin ${BUILD_DIR}/sbin

rm -rf ${BUILD_DIR}/usr/include
rm -rf ${BUILD_DIR}/usr/local/include
rm -rf ${BUILD_DIR}/usr/share/doc
rm -rf ${BUILD_DIR}/usr/share/man
find ${BUILD_DIR}/usr ${BUILD_DIR}/opt -name '*.a' -delete
find ${BUILD_DIR}/opt -name '__pycache__' -type d -prune -exec rm -rf {} +

SNAP=/snap/immich/current
mkdir -p ${SNAP}
ln -sfn ${BUILD_DIR} ${SNAP}/ml

find ${BUILD_DIR}/usr ${BUILD_DIR}/opt -type l -lname '/*' | while read -r link; do
    target=$(readlink "${link}")
    ln -sfn "$(realpath -m --relative-to="$(dirname "${link}")" "${BUILD_DIR}${target}")" "${link}"
done

# a venv records an absolute home and its python finds no stdlib without this
sed -i "s#^home = .*#home = ${SNAP}/ml/usr/local/bin#" ${BUILD_DIR}/opt/venv/pyvenv.cfg

LD=$(ls ${SNAP}/ml/usr/lib/*-linux-*/ld-linux-*.so.* ${SNAP}/ml/usr/lib/*-linux-*/ld-[0-9]*.so 2>/dev/null | head -1)
LIBS=$(echo ${SNAP}/ml/usr/lib/*-linux-gnu*)
LIBS=${LIBS}:${SNAP}/ml/usr/lib:${SNAP}/ml/usr/local/lib

PYTHON=$(echo ${BUILD_DIR}/usr/local/bin/python3.[0-9]*)
PYTHON=$(echo ${PYTHON} | tr ' ' '\n' | grep -v config | head -1)

# the rpath must be set before the interpreter and in a separate call
patchelf --force-rpath --set-rpath ${LIBS} ${PYTHON}
patchelf --set-interpreter ${LD} ${PYTHON}

for lib in ${BUILD_DIR}/usr/local/lib/libpython*.so*; do
    [ -e "${lib}" ] || continue
    patchelf --force-rpath --set-rpath ${LIBS} ${lib}
done

du -sh ${BUILD_DIR}
