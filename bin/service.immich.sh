#!/bin/bash -e

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )

${DIR}/bin/wait-for-configure.sh

. "${SNAP_DATA}/config/env"

export NODE_ENV=production
export NODE_EXTRA_CA_CERTS=/var/snap/platform/current/syncloud.ca.crt
export PATH=${DIR}/immich/path:${PATH}
export TMPDIR=${SNAP_DATA}/tmp
export HOME=${SNAP_DATA}

cd ${DIR}/immich/usr/src/app/server
exec ${DIR}/immich/usr/local/bin/node ${DIR}/immich/usr/src/app/server/dist/main.js
