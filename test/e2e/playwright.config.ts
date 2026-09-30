import { defineConfig, devices } from '@playwright/test'
import { env } from './helpers/env'

const fullDomain = env('PLAYWRIGHT_FULL_DOMAIN')
const appDomain = env('PLAYWRIGHT_APP_DOMAIN')
const artifactDir = env('PLAYWRIGHT_ARTIFACT_DIR')

export default defineConfig({
  testDir: './specs',
  fullyParallel: false,
  workers: 1,
  retries: process.env.CI ? 1 : 0,
  maxFailures: 1,
  reporter: [['list'], ['html', { outputFolder: `${artifactDir}/playwright/report`, open: 'never' }]],
  outputDir: `${artifactDir}/playwright/test-results`,
  globalTeardown: './globalTeardown.ts',
  timeout: 600_000,
  expect: { timeout: 60_000 },
  use: {
    baseURL: `https://${appDomain}`,
    ignoreHTTPSErrors: true,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'on',
  },
  projects: [
    {
      name: 'desktop',
      use: { ...devices['Desktop Chrome'], viewport: { width: 1440, height: 960 } },
    },
  ],
  metadata: { appDomain, fullDomain, artifactDir },
})
