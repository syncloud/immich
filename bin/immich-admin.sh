#!/bin/bash -e

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )

. "${SNAP_DATA}/config/env"

export NODE_ENV=production
export NODE_EXTRA_CA_CERTS=/var/snap/platform/current/syncloud.ca.crt
export PATH=${DIR}/immich/path:${PATH}
export TMPDIR=${SNAP_DATA}/tmp
export HOME=${SNAP_DATA}

cd ${DIR}/immich/usr/src/app/server
if [[ "$(whoami)" == "immich" ]]; then
    exec ${DIR}/immich/usr/local/bin/node dist/main.js immich-admin "$@"
else
    exec sudo -E -H -u immich ${DIR}/immich/usr/local/bin/node dist/main.js immich-admin "$@"
fi
