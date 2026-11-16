import { defineConfig } from '@playwright/test';
import staging from './playwright.staging.config';
export default defineConfig(staging, {
  testMatch: ['native_gradebook_acceptance.spec.ts'],
  use: { ...staging.use, actionTimeout: 30_000, navigationTimeout: 60_000 },
});
