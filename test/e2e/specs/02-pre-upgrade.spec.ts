import { test, expect } from '../fixtures'
import { shoot } from '../helpers/screenshot'
import { login, uploadPhoto, expectAssetCount, expectAdmin, assets, deviceUser, devicePassword } from '../helpers/immich'

test('immich before upgrade', async ({ page }) => {
  await test.step('seed a photo that has to survive the refresh', async () => {
    await login(page, deviceUser, devicePassword)
    await uploadPhoto(page, 'sample.jpg')
    await expectAssetCount(page, 1)
    await expect(assets(page).first().locator('img')).toBeVisible()
    await shoot(page, 'photos-before-upgrade')
  })

  await test.step('an existing admin is still an admin on the next login', async () => {
    await expectAdmin(page, deviceUser, true)
  })
})
