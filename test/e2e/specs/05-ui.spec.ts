import { test, expect } from '@playwright/test'
import { shoot } from '../helpers/screenshot'
import {
  login,
  uploadPhoto,
  assets,
  expectAssetCount,
  openAdministration,
  primaryNav,
  deviceUser,
  devicePassword,
} from '../helpers/immich'

test.describe('immich ui', () => {
  test('upload a photo and open it', async ({ page }, testInfo) => {
    await login(page, deviceUser, devicePassword)
    await shoot(page, testInfo, 'timeline-empty')

    await uploadPhoto(page, 'sample.jpg')
    await expectAssetCount(page, 1)
    await shoot(page, testInfo, 'timeline')

    await assets(page).first().click()
    await expect(page.getByRole('button', { name: 'Go back' })).toBeVisible()
    await expect(page.getByRole('button', { name: 'Info', exact: true })).toBeVisible()
    await shoot(page, testInfo, 'photo')
  })

  test('create an album', async ({ page }, testInfo) => {
    await login(page, deviceUser, devicePassword)

    await primaryNav(page).getByRole('link', { name: 'Albums' }).click()
    await expect(page.getByRole('button', { name: 'Create album' })).toBeVisible()
    await shoot(page, testInfo, 'albums')

    await page.getByRole('button', { name: 'Create album' }).click()
    await expect(page.getByRole('textbox', { name: 'Edit Title' })).toBeVisible()
    await shoot(page, testInfo, 'album')
  })

  test('the admin pages render', async ({ page }, testInfo) => {
    await login(page, deviceUser, devicePassword)
    await openAdministration(page, deviceUser)

    await page.getByRole('link', { name: 'Users', exact: true }).click()
    await expect(page.getByRole('table')).toBeVisible()
    await shoot(page, testInfo, 'admin-users')

    await page.getByRole('link', { name: 'Job Queues', exact: true }).click()
    await expect(page.getByRole('link', { name: 'Generate Thumbnails' })).toBeVisible()
    await shoot(page, testInfo, 'admin-queues')

    await page.getByRole('link', { name: 'Settings', exact: true }).click()
    await expect(page.getByRole('textbox', { name: 'Search settings' })).toBeVisible()
    await expect(page.getByRole('heading', { name: 'Authentication Settings' })).toBeVisible()
    await shoot(page, testInfo, 'admin-settings')

    await page.getByRole('link', { name: 'Server Stats', exact: true }).click()
    await expect(page.getByText('Total usage')).toBeVisible()
    await shoot(page, testInfo, 'admin-stats')
  })
})
