import { test, expect } from '@playwright/test'
import { shoot } from '../helpers/screenshot'
import {
  login,
  expectApp,
  expectAdmin,
  openSettings,
  openSettingsSection,
  saveSettings,
  openPhotos,
  deviceUser,
  devicePassword,
} from '../helpers/immich'

test.describe('immich smoke', () => {
  test('the login page offers syncloud sso', async ({ page }, testInfo) => {
    await page.goto('/')
    await expect(page.getByRole('heading', { name: 'Login' })).toBeVisible()
    await expect(page.getByRole('button', { name: 'Login with Syncloud' })).toBeVisible()
    await shoot(page, testInfo, 'login')
  })

  test('log in through syncloud sso as an admin', async ({ page }, testInfo) => {
    await login(page, deviceUser, devicePassword)
    await expectApp(page)
    await shoot(page, testInfo, 'photos')
    await expectAdmin(page, deviceUser, true)
  })

  test('an existing admin is still an admin on the next login', async ({ page }) => {
    await login(page, deviceUser, devicePassword)
    await expectAdmin(page, deviceUser, true)
  })

  test('the admin can change a setting the installer does not force', async ({ page }) => {
    await login(page, deviceUser, devicePassword)
    await openSettings(page, deviceUser)

    await openSettingsSection(page, 'Trash Settings')
    const days = page.getByRole('spinbutton', { name: 'Number of days' })
    await expect(days).toBeEnabled()
    await days.fill('14')
    await saveSettings(page)

    await openPhotos(page)
    await openSettings(page, deviceUser)
    await openSettingsSection(page, 'Trash Settings')
    await expect(days).toHaveValue('14')
  })

  test('a setting the installer forces comes back after the admin changes it', async ({ page }) => {
    await login(page, deviceUser, devicePassword)
    await openSettings(page, deviceUser)

    await openSettingsSection(page, 'Version Check')
    const versionCheck = page.getByRole('switch', { name: 'Enable version check' })
    await expect(versionCheck).toBeEnabled()
    await expect(versionCheck).not.toBeChecked()

    await versionCheck.click()
    await saveSettings(page)

    await openPhotos(page)
    await openSettings(page, deviceUser)
    await openSettingsSection(page, 'Version Check')
    await expect(versionCheck).not.toBeChecked()
  })
})
