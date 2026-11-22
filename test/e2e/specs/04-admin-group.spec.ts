import { test } from '../fixtures'
import { login, expectAdmin } from '../helpers/immich'
import { addUser, removeUser, setAdmin } from '../helpers/platform'

const username = 'immichdemote'
const password = 'Password1'

test.afterEach(() => {
  removeUser(username)
})

test('immich admin group mapping', async ({ page }) => {
  removeUser(username)
  addUser(username, password, true)

  await test.step('a second syncloud admin signs in as an immich admin', async () => {
    await login(page, username, password)
    await expectAdmin(page, username, true)
  })

  await test.step('losing the group takes immich admin away on the next login', async () => {
    await setAdmin(username, false)
    await page.context().clearCookies()
    await login(page, username, password)
    await expectAdmin(page, username, false)
  })
})
