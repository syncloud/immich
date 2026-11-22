import { test, expect } from '../fixtures'
import { shoot } from '../helpers/screenshot'
import {
  login,
  uploadPhoto,
  assets,
  expectAssetCount,
  openAdministration,
  primaryNav,
  openPhotos,
  deviceUser,
  devicePassword,
} from '../helpers/immich'

test('immich ui', async ({ page }) => {
  await test.step('upload a photo and open it', async () => {
    await login(page, deviceUser, devicePassword)
    await shoot(page, 'timeline-empty')

    await uploadPhoto(page, 'sample.jpg')
    await expectAssetCount(page, 1)
    await shoot(page, 'timeline')

    await assets(page).first().click()
    await expect(page.getByRole('button', { name: 'Go back' })).toBeVisible()
    await expect(page.getByRole('button', { name: 'Info', exact: true })).toBeVisible()
    await shoot(page, 'photo')

    await page.getByRole('button', { name: 'Go back' }).click()
    await expect(primaryNav(page)).toBeVisible()
  })

  await test.step('a HEIC photo gets a thumbnail', async () => {
    await uploadPhoto(page, 'sample.heic')

    let id = ''
    await expect(async () => {
      const search = await page.request.post('/api/search/metadata', { data: { originalFileName: 'sample.heic' } })
      expect(search.status()).toBe(200)
      const items = (await search.json()).assets.items
      expect(items).toHaveLength(1)
      id = items[0].id
    }).toPass({ timeout: 300_000, intervals: [2_000] })

    await expect(async () => {
      const thumbnail = await page.request.get(`/api/assets/${id}/thumbnail?size=thumbnail`)
      expect(thumbnail.status()).toBe(200)
      expect(thumbnail.headers()['content-type']).toMatch(/^image\//)
    }).toPass({ timeout: 300_000, intervals: [5_000] })
    await shoot(page, 'heic')
  })

  await test.step('the admin pages render', async () => {
    await openAdministration(page, deviceUser)

    await page.getByRole('link', { name: 'Users', exact: true }).click()
    await expect(page.getByRole('table')).toBeVisible()
    await shoot(page, 'admin-users')

    await page.getByRole('link', { name: 'Job Queues', exact: true }).click()
    await expect(page.getByRole('link', { name: 'Generate Thumbnails' })).toBeVisible()
    await shoot(page, 'admin-queues')

    await page.getByRole('link', { name: 'Settings', exact: true }).click()
    await expect(page.getByRole('textbox', { name: 'Search settings' })).toBeVisible()
    await expect(page.getByRole('heading', { name: 'Authentication Settings' })).toBeVisible()
    await shoot(page, 'admin-settings')

    await page.getByRole('link', { name: 'Server Stats', exact: true }).click()
    await expect(page.getByText('Total usage')).toBeVisible()
    await shoot(page, 'admin-stats')
  })

  await test.step('create an album', async () => {
    await openPhotos(page)
    await primaryNav(page).getByRole('link', { name: 'Albums' }).click()
    await expect(page.getByRole('button', { name: 'Create album' })).toBeVisible()
    await shoot(page, 'albums')

    await page.getByRole('button', { name: 'Create album' }).click()
    await expect(page.getByRole('textbox', { name: 'Edit Title' })).toBeVisible()
    await shoot(page, 'album')
  })
})
