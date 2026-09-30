import { test } from '@playwright/test'
import { login, expectAdmin } from '../helpers/immich'
import { addUser, removeUser, setAdmin } from '../helpers/platform'

const username = 'immichdemote'
const password = 'Password1'

test.describe('immich admin group mapping', () => {
  test.afterAll(() => {
    removeUser(username)
  })

  test('a second syncloud admin signs in as an immich admin', async ({ page }) => {
    addUser(username, password, true)
    await login(page, username, password)
    await expectAdmin(page, username, true)
  })

  test('losing the group takes immich admin away on the next login', async ({ page }) => {
    await setAdmin(username, false)
    await login(page, username, password)
    await expectAdmin(page, username, false)
  })
})
