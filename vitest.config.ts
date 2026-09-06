import { fileURLToPath, URL } from "node:url";

import { playwright } from "@vitest/browser-playwright";
import { defaultExclude, defineConfig } from "vitest/config";

// Two Vitest projects, split by what the code under test actually needs -- not by history.
//
// - "unit" (environment: "node"): parsers, validators, URL/cookie encoding, serializers, state
//   machines, and React components that render through `react-dom/server`'s
//   `renderToStaticMarkup`, which produces a markup string without touching a DOM at all. None of
//   this needs jsdom or a browser; running it in one only made it slower.
// - "component" (Vitest Browser Mode, real headless Chromium via the official Playwright
//   provider): React component mounting, React Aria focus/keyboard/pointer behavior, Cookie Store
//   API, `matchMedia`, and Stimulus controllers that connect to real DOM elements. These need a
//   real browser: jsdom does not implement `navigator.credentials`, the Cookie Store API, or
//   `Element.scrollTo`, so spec/setup.ts previously stood in for all three. In Browser Mode those
//   are the browser's own implementations; see spec/setup.browser.ts.
//
// Neither project starts Rails, `vite dev`, `vite preview`, or any other externally managed
// server. Browser Mode serves its own test modules over its own internal dev server; that is not
// the Umaxica application server and is not confused with one anywhere in this config.
//
// File list, not folder split: the two kinds of test live side by side in the same directories
// (a components test next to its component, `spec/lib/payload.test.ts` next to five DOM-dependent
// siblings in the same folder), so the boundary is an explicit file list per project rather than a
// glob. `git mv` was deliberately not used -- moving files into a mirrored `spec-node/` tree would
// have changed every one of their relative imports for no behavioral gain.
//
// The list below was built by grepping every spec for DOM markers (`document.`, `window.`,
// `render(`, `@testing-library/react`, ...), then proven by running the candidates: two files
// (`spec/controllers/index.test.ts`, `spec/controllers/passkey_ceremony.test.ts`) looked pure by
// that grep but import code that reads `window.location` or calls `document.querySelector`
// transitively (`src/controllers/application.ts`, `src/lib/csrf.ts`), so they stayed in the
// browser project. That failure is the reason this list is files that were actually run green
// under `environment: "node"`, not files that merely looked DOM-free.
const srcRoot = fileURLToPath(new URL("./src", import.meta.url));
const specRoot = fileURLToPath(new URL("./spec", import.meta.url));

// Files whose behavior does not depend on a DOM: pure logic, and React components exercised only
// through `renderToStaticMarkup`. Kept in one place so "which project owns this file" has a single
// answer instead of one encoded into two glob patterns that have to stay in sync by hand.
const nodeSpecs = [
  "spec/lib/payload.test.ts",
  "spec/entrypoints/application.test.ts",
  "spec/entrypoints/bootstrap_entrypoints.test.ts",
  "spec/controllers/webauthn_utils.test.ts",
  "spec/features/auth/passkeys/messages.test.ts",
  "spec/features/landing/surface_root_landing.test.tsx",
  "spec/pages/base/app/groups/index.test.tsx",
  "spec/features/preferences/preference_index.test.tsx",
  "spec/features/landing/root_landing.test.tsx",
  "spec/features/auth/auth_com_screens.test.tsx",
  "spec/pages/base/app/identity/identity_pages.test.tsx",
  "spec/features/dashboards/side_dashboard.test.tsx",
  "spec/features/base_com/base_com_identity_pages.test.tsx",
  "spec/features/auth/session/sign_out_screens.test.tsx",
  "spec/features/auth/dashboard/surface_dashboard.test.tsx",
  "spec/features/identity/activity_index.test.tsx",
  "spec/pages/auth/app/settings/settings_screens.test.tsx",
  "spec/pages/palm/app/sign_outs/show.test.tsx",
  "spec/features/preferences/preference_screens.test.tsx",
  "spec/features/auth/signin/signin_screens.test.tsx",
  "spec/features/auth/auth_com_signup_screens.test.tsx",
  "spec/features/auth/verification/verification_screens.test.tsx",
].map((path) => fileURLToPath(new URL(`./${path}`, import.meta.url)));

// Options every project shares. Project-scoped only: root-only options (passWithNoTests,
// dangerouslyIgnoreUnhandledErrors, teardownTimeout, slowTestThreshold, coverage, reporters, ...)
// live on the top-level `test` block below instead -- Vitest rejects them here.
const sharedProjectDefaults = {
  allowOnly: false,
  retry: 0,
  isolate: true,
  fileParallelism: true,
  mockReset: true,
  restoreMocks: true,
  unstubEnvs: true,
  unstubGlobals: true,
  globals: true,
  testTimeout: 5_000,
  hookTimeout: 5_000,
} as const;

export default defineConfig({
  resolve: {
    // Must stay identical to the alias in vite.config.ts and to `paths` in tsconfig.app.json.
    alias: { "@": srcRoot },
  },
  test: {
    // Fail-closed run-level defaults.
    //
    // - passWithNoTests: false -- an empty run (a bad `--project` filter, a typo'd path) fails
    //   instead of reading as a green, zero-test pass.
    // - dangerouslyIgnoreUnhandledErrors: false -- an unhandled rejection or thrown error outside
    //   an assertion fails the run instead of being swallowed.
    // - teardownTimeout -- a hook that never resolves fails fast and names itself, instead of
    //   hanging until CI's own outer timeout kills the whole job with nothing attributed.
    // - slowTestThreshold: a real-browser component test legitimately costs more per test (page
    //   and context bookkeeping) than a Node unit test, so this is set for the slower of the two
    //   projects; a unit test this "slow" is still worth a second look; it just is not failed for
    //   it, which is what `testTimeout` is for.
    passWithNoTests: false,
    dangerouslyIgnoreUnhandledErrors: false,
    teardownTimeout: 5_000,
    slowTestThreshold: 1_000,
    fileParallelism: true,
    projects: [
      {
        // Inline project config (not a path to another vitest.config.ts): both projects share this
        // file's alias and coverage settings, so splitting into separate config files would only
        // reproduce them twice.
        extends: true,
        test: {
          ...sharedProjectDefaults,
          name: "unit",
          environment: "node",
          include: nodeSpecs,
          setupFiles: [],
        },
      },
      {
        extends: true,
        test: {
          ...sharedProjectDefaults,
          name: "component",
          include: [`${specRoot}/**/*.{test,spec}.{ts,tsx,js,jsx}`],
          exclude: [...defaultExclude, ...nodeSpecs],
          setupFiles: ["./spec/setup.browser.ts"],
          browser: {
            enabled: true,
            provider: playwright(),
            headless: true,
            // One shared instance keeps the matrix to what this repo actually ships: Chromium is
            // the only engine the Playwright E2E suite (playwright.config.ts) and every
            // React-Aria/browser-event assumption in this codebase target.
            instances: [{ browser: "chromium" }],
          },
        },
      },
    ],
    coverage: {
      provider: "v8",
      reportsDirectory: "coverage/vite",
      // HTML is kept for local debugging; text/lcov/json-summary are the machine-readable formats
      // CI and any future coverage-diff tooling read.
      reporter: ["text", "html", "lcov", "json-summary"],
      include: [`${srcRoot}/**/*.{js,ts,jsx,tsx}`],
      // v8 coverage only sees a file once some project imports it, but with `coverage.include`
      // set (as it is here), Vitest still counts every file matching that glob even when nothing
      // imports it -- an untested source file is a visible 0%-covered file in the report and
      // fails the threshold below, instead of silently missing from the denominator.
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
        100: true,
        // Per-file, not just global: a 100% global average can still hide one abandoned file at
        // 40%, offset by everything else at 100%. Per-file closes that gap.
        perFile: true,
      },
    },
  },
});
