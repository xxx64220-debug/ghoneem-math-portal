const { defineConfig } = require('@playwright/test');
module.exports = defineConfig({
  testDir: '.', testMatch: '*.spec.cjs', timeout: 30000, retries: 0,
  use: { baseURL: 'http://127.0.0.1:4173', serviceWorkers: 'block', trace: 'retain-on-failure' },
  projects: [
    { name: 'desktop', use: { browserName: 'chromium', viewport: { width: 1280, height: 800 } } },
    { name: 'mobile', use: { browserName: 'chromium', viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true } }
  ],
  webServer: { command: 'python3 -m http.server 4173 --bind 127.0.0.1 --directory ../../web', url: 'http://127.0.0.1:4173', reuseExistingServer: false }
});
