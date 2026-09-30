#!/bin/bash -ex

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd ${DIR}

BUILD_DIR=${DIR}/../build/snap/immich
rm -rf ${BUILD_DIR}
mkdir -p ${BUILD_DIR}

${DIR}/../ci/apt.sh patchelf patch

cp -r /usr ${BUILD_DIR}
cp -r /build ${BUILD_DIR}/build

UNDICI=$(echo ${BUILD_DIR}/usr/src/app/server/node_modules/.pnpm/undici@*/node_modules/undici)
if [ ! -d "${UNDICI}" ]; then
    echo "expected exactly one undici in the pnpm store, found: ${UNDICI}" >&2
    exit 1
fi
ln -s "$(realpath -m --relative-to=${BUILD_DIR}/usr/src/app/server/node_modules ${UNDICI})" \
    ${BUILD_DIR}/usr/src/app/server/node_modules/undici

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
find ${BUILD_DIR}/usr -name '*.a' -delete
find ${BUILD_DIR}/usr -name '*.la' -delete

find ${BUILD_DIR}/usr -type l -lname '/*' | while read -r link; do
    target=$(readlink "${link}")
    ln -sfn "$(realpath -m --relative-to="$(dirname "${link}")" "${BUILD_DIR}${target}")" "${link}"
done

SNAP=/snap/immich/current
mkdir -p ${SNAP}
ln -sfn ${BUILD_DIR} ${SNAP}/immich

mkdir ${BUILD_DIR}/path
cp ${DIR}/path/perl ${BUILD_DIR}/path/perl
ln -s ../usr/local/bin/node ${BUILD_DIR}/path/node
ln -s ../usr/lib/jellyfin-ffmpeg/ffmpeg ${BUILD_DIR}/path/ffmpeg
ln -s ../usr/lib/jellyfin-ffmpeg/ffprobe ${BUILD_DIR}/path/ffprobe

LD=$(ls ${SNAP}/immich/usr/lib/*-linux-*/ld-linux-*.so.* ${SNAP}/immich/usr/lib/*-linux-*/ld-[0-9]*.so 2>/dev/null | head -1)
LIBS=$(echo ${SNAP}/immich/usr/lib/*-linux-gnu*)
LIBS=${LIBS}:${SNAP}/immich/usr/lib:${SNAP}/immich/usr/local/lib

# an object's own DT_RUNPATH wins over the rpath of whatever loads it
find ${BUILD_DIR}/usr \( -name '*.so' -o -name '*.so.*' -o -name '*.node' \) -type f | while read -r object; do
    rpath=$(patchelf --print-rpath "${object}" 2>/dev/null) || continue
    if [ -z "${rpath}" ]; then
        continue
    fi
    relocated=""
    while IFS= read -r entry; do
        case "${entry}" in
            /*) entry=${SNAP}/immich${entry} ;;
        esac
        relocated=${relocated:+${relocated}:}${entry}
    done < <(echo "${rpath}" | tr ':' '\n')
    patchelf --force-rpath --set-rpath "${relocated}" "${object}"
done

# the rpath must be set before the interpreter and in a separate call, or node
# segfaults; DT_RPATH rather than DT_RUNPATH because native addons dlopen later
patch() {
    patchelf --force-rpath --set-rpath "$2" ${BUILD_DIR}/$1
    patchelf --set-interpreter ${LD} ${BUILD_DIR}/$1
}

patch usr/local/bin/node ${LIBS}
patch usr/bin/perl ${LIBS}
patch usr/lib/jellyfin-ffmpeg/ffmpeg ${SNAP}/immich/usr/lib/jellyfin-ffmpeg/lib:${LIBS}
patch usr/lib/jellyfin-ffmpeg/ffprobe ${SNAP}/immich/usr/lib/jellyfin-ffmpeg/lib:${LIBS}

du -sh ${BUILD_DIR}
