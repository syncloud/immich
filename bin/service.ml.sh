#!/bin/bash -e

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd .. && pwd )

${DIR}/bin/wait-for-configure.sh

. "${SNAP_DATA}/config/env"

/bin/rm -f ${IMMICH_ML_SOCKET}
# onnxruntime's own DT_RUNPATH beats the interpreter rpath and finds the host
# glibc; LD_LIBRARY_PATH is searched ahead of it
MLLIBS=$(echo ${DIR}/ml/usr/lib/*-linux-gnu)
MLLIBS=${MLLIBS}:${DIR}/ml/usr/lib:${DIR}/ml/usr/local/lib

export LD_LIBRARY_PATH=${MLLIBS}
export PYTHONPATH=${DIR}/ml/usr/src
export PATH=${DIR}/ml/opt/venv/bin:${PATH}
export VIRTUAL_ENV=${DIR}/ml/opt/venv
export PYTHONDONTWRITEBYTECODE=1
export PYTHONUNBUFFERED=1
export TMPDIR=${SNAP_DATA}/tmp
export HOME=${SNAP_DATA}

export LD_PRELOAD=$(echo ${DIR}/ml/usr/lib/*-linux-gnu/libmimalloc.so.2)

exec ${DIR}/ml/opt/venv/bin/python -m immich_ml
