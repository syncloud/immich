#!/bin/bash -ex

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd ${DIR}

BUILD_DIR=${DIR}/../build/snap/immich

SNAP=/snap/immich/current
mkdir -p ${SNAP}
ln -sfn ${BUILD_DIR} ${SNAP}/immich

export PATH=${SNAP}/immich/path:${PATH}

node --version
perl --version
ffmpeg -version
ffprobe -version

test -f ${SNAP}/immich/build/www/index.html
test -f ${SNAP}/immich/usr/src/app/server/dist/main.js

cd ${SNAP}/immich/usr/src/app/server
node -e "require('sharp'); console.log('sharp ok')"
VIPSHOME=${SNAP}/immich/usr/local node -e "const f = require('sharp').format; if (!f.heif.input.file || !f.jxl.input.file) { process.exit(1) } console.log('sharp heif jxl ok')"
node -e "require('bcrypt'); console.log('bcrypt ok')"
node -e "require('postgres'); console.log('postgres ok')"

EXIFTOOL=$(find ${SNAP}/immich/usr/src/app/server/node_modules -path '*exiftool-vendored.pl*/bin/exiftool' | head -1)
perl ${EXIFTOOL} -ver
