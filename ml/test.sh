#!/bin/bash -ex

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd ${DIR}

BUILD_DIR=${DIR}/../build/snap/ml

SNAP=/snap/immich/current
mkdir -p ${SNAP}
ln -sfn ${BUILD_DIR} ${SNAP}/ml

PYTHON=${SNAP}/ml/opt/venv/bin/python

MLLIBS=$(echo ${SNAP}/ml/usr/lib/*-linux-gnu)
MLLIBS=${MLLIBS}:${SNAP}/ml/usr/lib:${SNAP}/ml/usr/local/lib

export LD_LIBRARY_PATH=${MLLIBS}
export PYTHONPATH=${SNAP}/ml/usr/src
export MACHINE_LEARNING_CACHE_FOLDER=/tmp/immich-ml-cache

${PYTHON} --version
${PYTHON} -c "import sys; print('prefix', sys.prefix)"
${PYTHON} -c "import onnxruntime; print('onnxruntime', onnxruntime.__version__)"
${PYTHON} -c "import cv2; print('cv2', cv2.__version__)"
${PYTHON} -c "import numpy; print('numpy', numpy.__version__)"
${PYTHON} -c "import gunicorn; print('gunicorn ok')"
${PYTHON} -c "import immich_ml; print('immich_ml ok')"
${PYTHON} - <<'PATCHED'
import pathlib
import sys

source = pathlib.Path('/snap/immich/current/ml/usr/src/immich_ml/__main__.py').read_text()
if 'IMMICH_ML_SOCKET' not in source:
    sys.exit('__main__.py is not patched for IMMICH_ML_SOCKET')
print('socket patch ok')
PATCHED
