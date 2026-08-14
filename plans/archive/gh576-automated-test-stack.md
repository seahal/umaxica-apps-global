# GH-576: Fill Gaps in the Automated Test Stack

> **Superseded — historical record only.** Vite Plus (`vp`) was removed from this repository on
> 2026-07-10. The current frontend toolchain is pnpm + Vite (via `vite-plugin-ruby`) + Vitest +
> Oxlint + Oxfmt; JavaScript commands are `package.json` scripts run through pnpm. Any statement
> below that Vite Plus or Rails Importmap is the current toolchain is out of date, and the `vp`
> commands below must not be run. See `notes/implementation/2026-07-10-vite-plus-removal.md` and
> `adr/frontend-architecture-toolchain.md`.

GitHub: #576

## Summary

Fill the remaining gaps in the automated test stack. Ruby tests use Minitest. JavaScript tests use
`vp test` (Vitest via Vite+), which is already adopted and has controller-level coverage.

## Scope

- Keep `vp test` as the JavaScript test baseline and expand coverage for frontend helpers/modules
  when behavior changes.
- Decide whether API/contract testing needs a dedicated tool beyond existing Rails integration tests
  and `committee-rails`.
- Decide whether browser-level E2E/system coverage should use Playwright, Capybara, or remain
  deferred.
- Decide whether performance test tooling (for example k6 or wrk) is needed now, and if so add one
  runnable scenario.
- Document the selected commands for each adopted layer and wire missing layers into CI only after
  the tool choice is explicit.

## Acceptance Criteria

- JavaScript unit tests continue to run through `vp test`.
- The adopted test layers have named local commands and CI coverage.
- API/contract, E2E/system, and performance testing each have an explicit decision: adopted with a
  first runnable scenario, or intentionally deferred with rationale.
- The docs reflect the actual selected tools, not an aspirational stack.

## Source

- `docs/test.md`

## Implementation Status (2026-05-07)

**Status: CLOSED 2026-05-10**

Decision:

- Ruby code uses Minitest.
- JavaScript uses `vp test` as the project test command (`package.json` maps it to `vp test run`).
- Vitest-style JavaScript tests already exist under `test/javascript/controllers/`, including
  passkey, WebAuthn utility, theme, cookie, OTP resend, and unsaved-changes coverage.
- API/contract testing stays in Rails controller/integration tests, with selective `committee-rails`
  validation where schemas exist. Rswag is not adopted.
- Browser-level E2E beyond Rails system tests is deferred until a named cross-browser release flow
  requires it.
- Performance tooling is deferred until concrete load targets and a staging-like execution
  environment are specified.
- `docs/test.md` now reflects the actual adopted layers and commands instead of the older
  aspirational stack.

## Improvement Points (2026-04-07 Review)

- Do not replace `vp test`; it is the selected JavaScript test baseline.
- Pick concrete tools only for the still-open layers. Avoid adding Rswag, Playwright, Capybara, or
  k6 just because they were named in the older target list.
- Add one "done means done" matrix that names the baseline command for each adopted layer so this
  plan can be closed incrementally.
