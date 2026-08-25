import { fileURLToPath, URL } from "node:url";

import { defineConfig } from "vitest/config";

const srcRoot = fileURLToPath(new URL("./src", import.meta.url));
const specRoot = fileURLToPath(new URL("./spec", import.meta.url));

export default defineConfig({
  resolve: {
    // Must stay identical to the alias in vite.config.ts and to `paths` in tsconfig.app.json.
    alias: { "@": srcRoot },
  },
  test: {
    allowOnly: false,
    dangerouslyIgnoreUnhandledErrors: false,
    environment: "jsdom",
    globals: true,
    include: [`${specRoot}/**/*.{test,spec}.{ts,tsx,js,jsx}`],
    retry: 0,
    setupFiles: ["./spec/setup.ts"],
    coverage: {
      provider: "v8",
      reportsDirectory: "coverage/vite",
      reporter: ["text", "html", "lcov", "json-summary"],
      include: [`${srcRoot}/**/*.{js,ts,jsx,tsx}`],
      exclude: [
        `${srcRoot}/**/*.d.ts`,
        `${srcRoot}/**/*.stories.{ts,tsx,js,jsx}`,
        `${srcRoot}/**/__fixtures__/**`,
        "**/node_modules/**",
        "**/dist/**",
        "**/build/**",
        "**/coverage/**",
        "public/vite/**",
      ],
      thresholds: {
        branches: 98,
        functions: 98,
        lines: 98,
        perFile: false,
        statements: 98,
      },
    },
  },
});
