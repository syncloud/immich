import { ssh, scpFrom } from './helpers/ssh'
import * as path from 'node:path'
import * as fs from 'node:fs'
import { execSync } from 'node:child_process'
import { env } from './helpers/env'

const TMP_DIR = '/tmp/syncloud/immich-ui'
const artifactRoot = env('PLAYWRIGHT_ARTIFACT_DIR')

export default async function () {
  const project = env('PLAYWRIGHT_PROJECT')
  const out = path.join(artifactRoot, 'playwright', project)
  fs.mkdirSync(out, { recursive: true })

  ssh(`mkdir -p ${TMP_DIR}`, { throw: false })
  ssh(`journalctl > ${TMP_DIR}/journalctl.log`, { throw: false })
  ssh(`snap services immich > ${TMP_DIR}/services.log 2>&1`, { throw: false })
  ssh(`ls -la /var/snap/immich/current/config > ${TMP_DIR}/config.ls.log 2>&1`, { throw: false })
  ssh(`cat /var/snap/immich/current/config/immich.json > ${TMP_DIR}/immich.json.log 2>&1`, { throw: false })
  scpFrom(`${TMP_DIR}/*`, out, { throw: false })
  try { execSync(`chmod -R a+r ${out}`) } catch {}
}
