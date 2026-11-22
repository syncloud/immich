import { test, expect } from '../fixtures'
import { shoot } from '../helpers/screenshot'
import {
  signIn,
  expectApp,
  openSettings,
  openSettingsSection,
  saveSettings,
  openPhotos,
  deviceUser,
  devicePassword,
} from '../helpers/immich'

test('immich smoke', async ({ page }) => {
  await test.step('the site sends you straight to syncloud sso', async () => {
    await page.goto('/')
    await expect(page.locator('#username-textfield')).toBeVisible()
    await expect(page.locator('#sign-in-button')).toBeVisible()
    await shoot(page, 'login')
  })

  await test.step('log in through syncloud sso as an admin', async () => {
    await signIn(page, deviceUser, devicePassword)
    await expectApp(page)
    await shoot(page, 'photos')
  })

  const days = page.getByRole('spinbutton', { name: 'Number of days' })

  await test.step('the admin can change a setting the installer does not force', async () => {
    await openSettings(page, deviceUser)
    await openSettingsSection(page, 'Trash Settings')
    await expect(days).toBeEnabled()
    await days.fill('14')
    await saveSettings(days)
  })

  await test.step('the changed setting is kept', async () => {
    await openPhotos(page)
    await openSettings(page, deviceUser)
    await openSettingsSection(page, 'Trash Settings')
    await expect(days).toHaveValue('14')
  })

  const versionCheck = page.getByRole('switch', { name: 'Enable version check' })

  await test.step('the admin flips a setting the installer forces', async () => {
    await openSettingsSection(page, 'Version Check')
    await expect(versionCheck).toBeEnabled()
    await expect(versionCheck).not.toBeChecked()
    await versionCheck.click()
    await saveSettings(versionCheck)
  })

  await test.step('the forced setting comes back', async () => {
    await openPhotos(page)
    await openSettings(page, deviceUser)
    await openSettingsSection(page, 'Version Check')
    await expect(versionCheck).not.toBeChecked()
    await shoot(page, 'settings')
  })
})
