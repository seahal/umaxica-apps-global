# DBSC Performance Improvement Plan

## Problem

The calculation of DBSC itself is not heavy, but currently `set_preferences_cookie` DBSC challenges
are issued and preferences are updated even when the page is displayed via `show`. or unnecessary
writes are occurring on root.

## Goal

- DBSC write is not generated when displaying a public page.
- Issuance and updates of DBSC should only be sent to the dedicated endpoint.
- Reduce the number of SQL per request and latency.

## Proposed Steps

1. Organize `show` and root's before_action, and fix screens that do not require
   `set_preferences_cookie`.
2. DBSC challenge is issued only to registration/verification endpoints.
3. Find a route that does not run unnecessary `update!`, and add cache or conditional branching if
   necessary.
4. `App/Org/Com` Place regression tests on each surface to ensure that preferences are not updated
   on public pages.

## Verification

- Add/update target controller test of `bin/rails test`.
- If possible, remeasure the number of SQL of `/?ri=jp` and `PreferencesController#show`.

## Notes

- This is not a problem with the DBSC protocol itself, but rather a problem with how to use the
  controller pipeline.
- The first priority is to stop writes, and optimization of cryptographic processing is a secondary
  response.
