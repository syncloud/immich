#!/bin/bash -e

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )

/bin/rm -f ${SNAP_DATA}/redis.sock
exec ${DIR}/redis/bin/redis.sh ${SNAP_DATA}/config/redis.conf
