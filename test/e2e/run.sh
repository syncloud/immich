#!/bin/bash -eu
# usage: run.sh <artifact-subdir> <spec> <project>
DIR=$(cd "$(dirname "$0")" && pwd)
cd "$DIR"

ARTIFACT_SUBDIR=$1
SPEC=$2
PROJECT=$3

export PLAYWRIGHT_PROJECT=${PROJECT}
export PLAYWRIGHT_ARTIFACT_DIR=/drone/src/artifact/${ARTIFACT_SUBDIR}

"${DIR}/../../ci/apt.sh" sshpass openssh-client curl
DEVICE_IP=$(getent hosts "${PLAYWRIGHT_APP_DOMAIN}" | head -1 | cut -d' ' -f1)
echo "${DEVICE_IP} auth.${PLAYWRIGHT_FULL_DOMAIN} ${PLAYWRIGHT_FULL_DOMAIN}" | tee -a /etc/hosts
"${DIR}/wait-app.sh" "${PLAYWRIGHT_APP_DOMAIN}"
"${DIR}/../../ci/npm.sh"
npx playwright test --project="${PLAYWRIGHT_PROJECT}" "${SPEC}"
