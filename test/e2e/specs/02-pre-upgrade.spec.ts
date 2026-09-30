import { test, expect } from '@playwright/test'
import { shoot } from '../helpers/screenshot'
import { login, uploadPhoto, expectAssetCount, assets, deviceUser, devicePassword } from '../helpers/immich'

test.describe('immich before upgrade', () => {
  test('seed a photo that has to survive the refresh', async ({ page }, testInfo) => {
    await login(page, deviceUser, devicePassword)
    await uploadPhoto(page, 'sample.jpg')
    await expectAssetCount(page, 1)
    await expect(assets(page).first().locator('img')).toBeVisible()
    await shoot(page, testInfo, 'before-upgrade')
  })
})
