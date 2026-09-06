# Vitest architecture hardening: Node unit project + real-browser component project

## Scope

Redesigned `vitest.config.ts` from a single jsdom project into two Vitest 4 `projects`, split by
what the code under test actually needs, per the request in this session. Working tree is on branch
`feature`, uncommitted on top of harness checkpoint `35d33eafd`.

## Starting configuration

One project, `environment: "jsdom"`, `globals 98%` thresholds (not per-file), `spec/setup.ts`
polyfilling `Element.scrollTo`, `window.matchMedia`, and the Cookie Store API for every spec
regardless of whether the spec under test needed a DOM at all. 84 spec files, all under jsdom.

## Architectural changes

- **Two projects** (`vitest.config.ts`, `test.projects`): `unit` (`environment: "node"`) and
  `component` (Vitest Browser Mode, `@vitest/browser-playwright`, Chromium, headless). Both
  `extends: true` from the root config so the `@` alias and coverage settings are declared once.
- **File-list boundary, not a folder split.** `nodeSpecs` in `vitest.config.ts` is an explicit list
  of 22 files proven to run green under `environment: "node"`; the `component` project's `include`
  is every spec file, `exclude` is that same list. Two files that looked DOM-free by a static grep
  (`document.`, `window.`, `render(`, `@testing-library/react`) turned out to import code that reads
  `window.location` or calls `document.querySelector` transitively
  (`src/controllers/application.ts`, `src/lib/csrf.ts`) and were moved to `component` after they
  failed under Node -- the list is derived from an actual green run, not from the grep alone. Files
  were not moved on disk (`git mv`): they live in the same directories as their browser-project
  siblings, so moving them would have rewritten 22 files' relative imports for no behavioral gain.
- **`spec/setup.ts` deleted.** Its three shims existed only because jsdom lacks `Element.scrollTo`,
  `window.matchMedia`, and the Cookie Store API. In Vitest Browser Mode those are the real Chromium
  implementations, and neither project imports the file any more -- `unit` needs none of it (no DOM
  at all), `component` runs in a real browser. Per the retention rule given for this task ("retain a
  shim only when the tested behavior is not intended to depend on the real browser API"), all three
  describe behavior that is intended to depend on the real API, so none qualified to keep. Replaced
  by `spec/setup.browser.ts`, which keeps only `@testing-library/react`'s `cleanup()` -- DOM hygiene
  between tests, not a browser-API workaround, and equally real in Browser Mode.
- **`jsdom` dependency removed** from `package.json`/`pnpm-workspace.yaml` catalog (`pnpm install`
  ran clean, dropped it). Nothing imports it once no project declares `environment: "jsdom"`.
- **`@vitest/browser-playwright` added**, pinned to `4.1.11` in the `pnpm-workspace.yaml` catalog to
  match the already-pinned `vitest`/`@vitest/coverage-v8` version exactly (peer dependency is
  `vitest: 4.1.11` on the nose). Published 2026-08-18, past the repo's 3-day
  `minimumReleaseAgeStrict` quarantine.
- **Fail-closed defaults**: `allowOnly: false`, `passWithNoTests: false`, `retry: 0`,
  `isolate: true`, `fileParallelism: true`, `mockReset`/`restoreMocks`/`unstubEnvs`/
  `unstubGlobals: true`, `dangerouslyIgnoreUnhandledErrors: false`, explicit `testTimeout`/
  `hookTimeout`/`teardownTimeout` (5s each), `slowTestThreshold: 1000`. Vitest 4 splits config
  options between root-only (`passWithNoTests`, `dangerouslyIgnoreUnhandledErrors`,
  `teardownTimeout`, `slowTestThreshold`, `coverage`, ...) and per-project; the config places each
  on the side that actually accepts it, confirmed by `tsc --build` rejecting the wrong placement
  during iteration (see Commands executed).
- **Coverage**: provider `v8`, `reporter: [text, html, lcov, json-summary]`,
  `reportsDirectory: coverage/vite` (unchanged), `thresholds: { 100: true, perFile: true }` (was
  global 98%). `coverage.include` stays the `src/**/*.{js,ts,jsx,tsx}` glob it already was; in this
  Vitest version that alone is what makes an unimported source file show up as a visible 0%-covered
  file rather than silently missing from the denominator (the older `coverage.all` option no longer
  exists on `CoverageOptions` -- confirmed via `tsc --build` failing on it, then via the installed
  type declarations). `exclude` is unchanged from before this session (`*.d.ts`, `*.stories.*`,
  `__fixtures__`, build/coverage directories) -- no new exclusion was added, because none of the
  audited gaps turned out to need one (see "Coverage result" below).
- **Scripts** (`package.json`): added `test:unit` (`vitest run --project unit`), `test:component`
  (`vitest run --project component`), `test:stress`
  (`for i in 1 2 3; do vitest run --sequence.shuffle --detectAsyncLeaks || exit 1; done`). `test`
  (`vitest run`, both projects), `test:watch`, `test:coverage` (`vitest run --coverage`, both
  projects) kept their existing names and now run the new architecture without any other file
  changing. `ci`/`ci:js` were not touched and did not need to be -- they call `test:coverage`, which
  already covers both projects.

## Commands executed

```
pnpm info @vitest/browser-playwright versions/peerDependencies/time   # version + quarantine check
npx playwright install chromium                                       # browser binary only
pnpm install                                                          # add browser-playwright, drop jsdom
pnpm vitest run --project unit                                        # iterated to green, see below
pnpm run typecheck                                                    # iterated config shape to green
pnpm run format / pnpm run lint / pnpm run deadcode                   # clean
pnpm run build                                                        # production Vite build, clean
bin/rails test test/unit/security/ri_routing_contract_test.rb         # fixed by this session, see below
```

## Node ("unit") project result

22 files, 281 tests, all green under `environment: "node"` with no `setupFiles`. First attempt
included 25 files and failed 5 tests in 3 files with
`ReferenceError: window/document is not defined`, which is what moved
`spec/controllers/index.test.ts` and `spec/controllers/passkey_ceremony.test.ts` to the `component`
project (the third failing file, `spec/features/base_shared/surface_pages.test.tsx`, was never a
`nodeSpecs` candidate; its failure there was `SignOutConfirmation` calling `document.querySelector`
during render, the same `src/lib/csrf.ts` path). Final run: `22 passed (22)`, `281 passed (281)`.

## Browser ("component") project result: not executed

**This could not be verified in this sandbox, and that is the one significant gap in this
delivery.** `pnpm vitest run --project component` (and even `vitest list --project component`, which
only needs to discover tests) fails at browser launch:

```
chrome-headless-shell: error while loading shared libraries: libatk-1.0.so.0: cannot open shared
object file: No such file or directory
```

`npx playwright install-deps chromium` requires root (`su: Authentication failure`, no `sudo` binary
present). `apt-get install` as the unprivileged container user fails on the dpkg lock
(`Permission denied`). `apt-get download` (which does not need root) has no package to download:
this container's `/etc/apt/sources.list.d` carries only the Lefthook and Tailscale repositories, not
a general Debian/Ubuntu package mirror, so there is no source to fetch `libatk1.0-0` (or its dozen
siblings) from even without installing. This is a property of this specific dev container, not of
the Vitest/Playwright configuration: the config resolves without error up to the point Playwright
actually spawns the browser process, which is as far as configuration correctness can be shown
without the binary.

What this does verify: the `browser.provider`/`instances`/`headless` config is accepted by Vitest
(the only two failures before this were both config-shape errors -- a string
`provider: "playwright"` is rejected in this Vitest version in favor of the `playwright()` factory
import, fixed during iteration -- and both are gone once the config matched the installed version's
API).

**Required follow-up before this lands as a real gate**: run `pnpm run test:component` (or
`test:coverage`) once, either in a container with root/apt access
(`npx playwright install-deps chromium` once, or the individual
`libatk1.0-0 libatk-bridge2.0-0 libcups2 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libgbm1 libpango-1.0-0 libcairo2 libasound2`
set of packages) or in CI. GitHub's `ubuntu-latest` runners have full apt/root access, so
`.github/workflows/ci.yml`'s "JavaScript Checks" job should succeed once it installs the browser --
**but it currently does not run that install step, and this session could not add one**: `.github/`,
`.devcontainer/`, and `bin/` are read-only bind mounts in this container (confirmed:
`touch .github/x` -> `Read-only file system`), the same constraint
`evidence/2026-09-05-merge-package-update-and-review.md` recorded for the same three paths. The step
to add, once someone with write access to `.github/workflows/ci.yml` applies it, is a
`npx playwright install --with-deps chromium` (or `npx playwright install chromium` plus the package
list above) between `pnpm install --frozen-lockfile` and the
`pnpm --loglevel silent run test:coverage` step of the "JavaScript Checks" job. Until that lands,
`pnpm run test:coverage` in CI fails at browser launch exactly as it does here -- this is not a
passing CI run yet.

## Stress run: not executed for the same reason

`test:stress` covers both projects by default, so it inherits the same blocker. It was not run
narrowed to `--project unit` either, because order-dependency and leak detection are most useful
across the full suite, and a partial run would not have supported a real conclusion.

## Coverage result: not measured end to end

Because the `component` project cannot launch, no combined coverage number exists from this session.
A `--project unit`-only coverage run was tried as a smoke test and, as expected, reported 0% on
every file exercised only by `component`-project specs (hundreds of
`ERROR: Coverage ... does not meet global threshold` lines, e.g.
`src/pages/auth/org/social/sessions/new.tsx`) -- this is not a real gap, it is what filtering to one
project does when `coverage.include` still names the whole `src/` tree; it is included here only to
show the coverage plumbing itself works, not as a coverage result.

One specific concern was checked instead of guessed at: whether the ~283 files under `src/pages/`
(202 of them one-line `export { default } from "..."` re-export wrappers, the shape every publishing
CMS page added this session also takes) would show as untested 0% files once coverage threshold
became per-file 100%, which would have been exactly the "generated/framework-wiring code" case this
task's instructions ask to name and narrowly exclude rather than test file-by-file. They already are
not: `spec/entrypoints/inertia.test.ts` (an existing spec, correctly placed in the `component`
project because it manipulates `document.body` and the Cookie Store API) imports all thirteen
`src/entrypoints/inertia/*.tsx` files, and each of those calls
`import.meta.glob("../../pages/<surface>/**/*.tsx", { eager: true })` -- so every page file under
every surface is already eagerly imported, and therefore already coverage-instrumented, by
pre-existing test infrastructure this session did not have to add. No exclusion was added for
`src/pages/` on this basis; if real numbers surface a gap once the `component` project can run, that
is the moment to decide whether a narrower exclusion is warranted -- not before, per the instruction
not to add exclusions speculatively.

## Parallelism / worker benchmark

Benchmarked on this container's 24 physical cores (`nproc`), which is **not** representative of the
CI runner (GitHub `ubuntu-latest` is 2-4 vCPU) -- recorded here as what was measured, not as a
number to copy into CI. `unit` project only (the only one that can run here), 22 files / 281 tests:

| `--maxWorkers` | Duration (reported) |
| -------------- | ------------------- |
| 1              | 11.45s              |
| 12 (50%)       | 1.66s               |
| 18 (75%)       | 1.49s               |
| 24 (100%)      | 1.56s               |

75% was marginally fastest and 100% was very slightly slower (more worker-pool startup overhead than
benefit once the file count is this small), consistent with the instruction to prefer measurement
over the highest number. `vitest.config.ts` does not hardcode `maxWorkers`: with only 22 files in
`unit` and Browser Mode's own per-instance concurrency model in `component` (a shared browser
instance, not one-worker-per-file), a fixed number tuned to this container's 24 cores would be
closer to guessing than to the CI runner's real 2-4. `fileParallelism: true` and `isolate: true` are
set explicitly (both already Vitest defaults, stated for the record per the fail-closed requirement)
so parallel execution and per-file isolation are guaranteed rather than assumed; the worker _count_
is left to Vitest's own `Math.max(1, cpus - 1)`-shaped default, which already scales to whatever the
runner actually has. Re-benchmarking with the `component` project included, once it can run, is part
of the same follow-up as the coverage number above.

## Browser shims removed / retained

| Shim                                                       | Verdict                                    | Why                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| ---------------------------------------------------------- | ------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Element.prototype.scrollTo` no-op                         | Removed                                    | Real Chromium implements it.                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `window.matchMedia` stand-in                               | Removed                                    | Real Chromium implements it.                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `window.cookieStore` backed by `document.cookie`           | Removed                                    | Real Chromium implements the Cookie Store API on a secure context, and `localhost` (which is what Vitest Browser Mode serves from) is a secure context by spec. **Unverified in this session** -- listed here as the intended outcome, not a confirmed one, because the browser could not launch. If it turns out Browser Mode's origin does not satisfy the spec's secure-context check the way `localhost` normally does, this is the first thing to re-check once `test:component` can run. |
| `@testing-library/react` `cleanup()`                       | Retained, moved to `spec/setup.browser.ts` | Not a browser-API workaround -- it removes portal-rendered overlays (React Aria dialogs render into `document.body`) between tests. Real DOM hygiene, equally necessary in a real browser.                                                                                                                                                                                                                                                                                                     |
| `navigator.credentials` stub in `spec/support/webauthn.ts` | Retained as-is, now running in `component` | Its own comment already says "`navigator.credentials` is not implemented in jsdom, so it is stubbed" -- real Chromium _does_ implement it, so the stub's role changes from "polyfilling an absent API" to "controlling a real API for a deterministic, hardware-free ceremony result," which is legitimate and was not touched this session.                                                                                                                                                   |

## Parameter matrices

Not added new ones this session. The existing suite already uses `describe.each`/`test.each` for
real per-surface and per-input-shape matrices (`spec/entrypoints/bootstrap_entrypoints.test.ts`
across nine surface entrypoints, `spec/entrypoints/inertia.test.ts` across thirteen, this session's
own `src/forms/publishing/create_entry_form_test.rb`-style edge-of-format cases on the Rails side).
Given this session's actual failures were classification mistakes (two files that needed a real DOM)
rather than missing input-space coverage, no new matrix was invented to hit a count -- doing so
would have been exactly the "meaningless Cartesian product" the task warns against.

## Remaining limitations

1. **The `component` project has never been executed.** Everything about it beyond config resolution
   (browser launch, module transform under real Chromium, React Aria interaction, Cookie Store
   behavior, the 62 test files it now owns) is unverified in this session. This is the load-bearing
   gap in this delivery.
2. **CI does not yet install a browser.** `.github/workflows/ci.yml` needs one step added (see
   above); this session could not write to `.github/` (read-only bind mount) to add it.
3. **No combined coverage number exists.** The 100%/`perFile: true` threshold is what was asked for
   and is now configured, but it is unverified whether the existing test suite actually reaches it
   once the `component` project runs. It may not; per the task's own instructions, a real gap found
   there should be closed with a test first, and only receive a narrow, named, documented exclusion
   if the file is genuinely non-executable/generated -- not answered by softening the global
   threshold this session set.
4. **Worker-count benchmarks are Node-project-only and container-specific.** Re-benchmark once
   `component` can run and, ideally, on hardware closer to the actual CI runner's core count.
5. **The stress command (`test:stress`) has never been run.** Same blocker as above.
6. **Playwright browser binary is currently installed under this container's cache
   (`~/.cache/ms-playwright`) but its process still cannot execute** for the system-library reason
   above; this is separate from and does not resolve limitation 1.

## Commit / worktree identity

Branch `feature`, working tree on top of harness checkpoint commit `35d33eafd` (auto-checkpointed by
this environment during the session, not a commit this session made directly). All Vitest
architecture changes described here are uncommitted at the time of writing, per this repository's
policy of committing only when asked.
