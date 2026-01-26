import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['tests/integration.test.ts'],
    testTimeout: 120000, // 2min for cold starts + model loading
  },
});
