import { fileURLToPath, URL } from "node:url";

import { defineConfig } from "vitest/config";

const srcRoot = fileURLToPath(new URL("./src", import.meta.url));
const specRoot = fileURLToPath(new URL("./spec", import.meta.url));

export default defineConfig({
  resolve: {
    alias: {
      "@": fileURLToPath(new URL("./src", import.meta.url)),
      "~": fileURLToPath(new URL("./src", import.meta.url)),
      "@components": fileURLToPath(new URL("./src/components", import.meta.url)),
      "@controllers": fileURLToPath(new URL("./src/controllers", import.meta.url)),
      "@entrypoints": fileURLToPath(new URL("./src/entrypoints", import.meta.url)),
      "@styles": fileURLToPath(new URL("./src/styles", import.meta.url)),
      "react-aria-components": fileURLToPath(
        new URL("./src/vendor/react-aria-components.tsx", import.meta.url),
      ),
    },
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
        branches: 80,
        functions: 80,
        lines: 80,
        perFile: false,
        statements: 80,
      },
    },
  },
});
