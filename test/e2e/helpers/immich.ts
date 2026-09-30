import { Page, expect } from '@playwright/test'
import * as path from 'node:path'
import { env } from './env'

export const deviceUser = env('PLAYWRIGHT_DEVICE_USER')
export const devicePassword = env('PLAYWRIGHT_DEVICE_PASSWORD')
export const samples = env('PLAYWRIGHT_SAMPLES')

const timelineAsset = /Image taken on/

export function primaryNav(page: Page) {
  return page.getByRole('navigation', { name: 'Primary' })
}

export function uploadButton(page: Page) {
  return page.getByRole('button', { name: 'Upload', exact: true })
}

export function assets(page: Page) {
  return page.getByRole('link', { name: timelineAsset })
}

export async function login(page: Page, user: string, password: string) {
  await page.goto('/')

  const sso = page.getByRole('button', { name: 'Login with Syncloud' })
  await expect(sso).toBeEnabled()
  await sso.click()

  const username = page.locator('#username-textfield')
  await expect(username).toBeVisible()
  await username.fill(user)
  await page.locator('#password-textfield').fill(password)
  await page.locator('#sign-in-button').click()

  await finishOnboarding(page)
}

export async function finishOnboarding(page: Page) {
  const card = page.locator('#onboarding-card')
  const nav = primaryNav(page)

  await expect(async () => {
    if (await card.isVisible()) {
      await card.getByRole('button').last().click()
    }
    await expect(nav).toBeVisible({ timeout: 5_000 })
  }).toPass({ timeout: 300_000, intervals: [2_000] })
}

export async function expectApp(page: Page) {
  await expect(primaryNav(page)).toBeVisible()
  await expect(uploadButton(page)).toBeVisible()
}

export async function openAccountMenu(page: Page, user: string) {
  await page.getByRole('button', { name: `${user} (` }).click()
}

export async function expectAdmin(page: Page, user: string, admin: boolean) {
  await openAccountMenu(page, user)
  const administration = page.getByRole('link', { name: 'Administration' })
  if (admin) {
    await expect(administration).toBeVisible()
  } else {
    await expect(administration).toHaveCount(0)
  }
}

export async function openAdministration(page: Page, user: string) {
  await openAccountMenu(page, user)
  await page.getByRole('link', { name: 'Administration' }).click()
  await expect(page.getByRole('link', { name: 'Job Queues' })).toBeVisible()
}

export async function openSettings(page: Page, user: string) {
  await openAdministration(page, user)
  await page.getByRole('link', { name: 'Settings', exact: true }).click()
  await expect(page.getByRole('textbox', { name: 'Search settings' })).toBeVisible()
}

export async function openSettingsSection(page: Page, section: string) {
  await page.getByRole('button', { name: new RegExp('^' + section) }).click()
}

export async function saveSettings(page: Page) {
  await page.getByRole('button', { name: 'Save', exact: true }).click()
}

export async function uploadPhoto(page: Page, file: string) {
  const [chooser] = await Promise.all([
    page.waitForEvent('filechooser'),
    uploadButton(page).click(),
  ])
  await chooser.setFiles(path.join(samples, file))
}

export async function expectAssetCount(page: Page, count: number) {
  await expect(assets(page)).toHaveCount(count, { timeout: 300_000 })
}

export async function openPhotos(page: Page) {
  await page.getByRole('link', { name: 'Immich logo' }).first().click()
  await expect(primaryNav(page)).toBeVisible()
}
