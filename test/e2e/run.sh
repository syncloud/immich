#!/bin/bash -eu

DIR=$(cd "$(dirname "$0")" && pwd)
cd "$DIR"

SPEC=${1:?usage: run.sh <spec>}

export PLAYWRIGHT_FULL_DOMAIN=bookworm.com
export PLAYWRIGHT_APP_DOMAIN=immich.${PLAYWRIGHT_FULL_DOMAIN}
export PLAYWRIGHT_DEVICE_HOST=${PLAYWRIGHT_APP_DOMAIN}
export PLAYWRIGHT_DEVICE_USER=user
export PLAYWRIGHT_DEVICE_PASSWORD=Password1
export PLAYWRIGHT_SSH_USER=root
export PLAYWRIGHT_SSH_PASSWORD=Password1
export PLAYWRIGHT_SAMPLES=$(cd "${DIR}/../samples" && pwd)
export PLAYWRIGHT_ARTIFACT_DIR=$(cd "${DIR}/../.." && pwd)/artifact/screenshots
export PLAYWRIGHT_PROJECT=desktop

"${DIR}/../../ci/apt.sh" sshpass openssh-client curl
DEVICE_IP=$(getent hosts "${PLAYWRIGHT_APP_DOMAIN}" | head -1 | cut -d' ' -f1)
echo "${DEVICE_IP} auth.${PLAYWRIGHT_FULL_DOMAIN} ${PLAYWRIGHT_FULL_DOMAIN}" | tee -a /etc/hosts
"${DIR}/wait-app.sh" "${PLAYWRIGHT_APP_DOMAIN}"
"${DIR}/../../ci/npm.sh"
npx playwright test --project="${PLAYWRIGHT_PROJECT}" "${SPEC}"
