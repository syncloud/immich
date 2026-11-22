import { test, expect } from '../fixtures'
import { shoot } from '../helpers/screenshot'
import { login, expectAssetCount, expectAdmin, assets, deviceUser, devicePassword } from '../helpers/immich'

test('immich after upgrade', async ({ page }) => {
  await test.step('the seeded photo is still there', async () => {
    await login(page, deviceUser, devicePassword)
    await expectAssetCount(page, 1)
    await expect(assets(page).first().locator('img')).toBeVisible()
    await shoot(page, 'photos-after-upgrade')
  })

  await test.step('the admin is still an admin after the upgrade', async () => {
    await expectAdmin(page, deviceUser, true)
  })
})
