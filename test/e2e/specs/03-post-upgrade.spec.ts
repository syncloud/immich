import { test, expect } from '@playwright/test'
import { shoot } from '../helpers/screenshot'
import { login, expectAssetCount, assets, deviceUser, devicePassword } from '../helpers/immich'

test.describe('immich after upgrade', () => {
  test('the seeded photo is still there', async ({ page }, testInfo) => {
    await login(page, deviceUser, devicePassword)
    await expectAssetCount(page, 1)
    await expect(assets(page).first().locator('img')).toBeVisible()
    await shoot(page, testInfo, 'after-upgrade')
  })
})
