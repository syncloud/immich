import { request } from '@playwright/test'
import { ssh } from './ssh'
import { env } from './env'

const fullDomain = env('PLAYWRIGHT_FULL_DOMAIN')
const deviceUser = env('PLAYWRIGHT_DEVICE_USER')
const devicePassword = env('PLAYWRIGHT_DEVICE_PASSWORD')

export function addUser(username: string, password: string, admin: boolean) {
  const flags = [`--password ${password}`, `--email ${username}@${fullDomain}`]
  if (admin) {
    flags.push('--admin')
  }
  ssh(`snap run platform.cli user add ${username} ${flags.join(' ')}`)
}

export function removeUser(username: string) {
  ssh(`snap run platform.cli user remove ${username}`, { throw: false })
}

export async function setAdmin(username: string, admin: boolean) {
  const token = ssh(`snap run platform.cli login ${deviceUser} ${devicePassword}`).trim()

  const context = await request.newContext({
    baseURL: `https://${fullDomain}`,
    ignoreHTTPSErrors: true,
  })
  try {
    const login = await context.post('/rest/login/token', { data: { token } })
    if (!login.ok()) {
      throw new Error(`platform login failed: ${login.status()} ${await login.text()}`)
    }
    const response = await context.post('/rest/users/admin', { data: { username, admin } })
    if (!response.ok()) {
      throw new Error(`set admin failed: ${response.status()} ${await response.text()}`)
    }
  } finally {
    await context.dispose()
  }
}
