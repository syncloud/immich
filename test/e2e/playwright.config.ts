import { defineConfig, devices } from '@playwright/test'
import { env } from './helpers/env'

const appDomain = env('PLAYWRIGHT_APP_DOMAIN')

export default defineConfig({
  testDir: './specs',
  fullyParallel: false,
  workers: 1,
  retries: process.env.CI ? 1 : 0,
  maxFailures: 1,
  reporter: 'list',
  outputDir: '/tmp/playwright/test-results',
  timeout: 1_800_000,
  expect: { timeout: 60_000 },
  use: {
    baseURL: `https://${appDomain}`,
    ignoreHTTPSErrors: true,
  },
  projects: [
    {
      name: 'desktop',
      use: { ...devices['Desktop Chrome'], viewport: { width: 1440, height: 960 } },
    },
  ],
})
