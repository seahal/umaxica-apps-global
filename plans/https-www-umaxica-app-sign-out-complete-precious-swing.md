# Sign-out triple-confirmation regression — log analysis and fix plan

## Context

Reported symptom: signing out via `https://www.umaxica.app/sign/out/complete?ri=jp` requires the
user to press the "sign out" button **three times** before they reach the completion page. Log
inspection (`log/development.log` ≈ lines 331022–331765, and similar earlier cycles at 6256–6488,
8466–8688, 13779) confirms this. The flow is not looping — each press advances the coordinated
`AcmeLogoutTransaction` state machine (`origin_cleared` → `sign_cleared` → `acme_cleared` →
`finalized`) one step. The user just sees three back-to-back confirmation pages.

Observed request sequence on the `app` surface for a single sign-out intent:

1. `Acme::App::Sign::OutsController#new` (GET `/sign/out`) → 303 → `/sign/out/edit`
2. `Acme::App::Sign::OutsController#edit` (GET `/sign/out/edit`) — **renders confirmation form #1**
   (`acme/shared/sign_outs/edit.html.erb`)
3. User clicks `[sign-out]` → POST `/sign/out` (`#create`) — issues `AcmeLogoutTransaction`,
   advances `origin_cleared`, clears origin session, redirects via `jump.umaxica.net` to
   `id.umaxica.app/sign/out/edit?logout_challenge=…`
4. `Sign::App::Sign::OutsController#edit` (GET) — **renders confirmation form #2**
   (`sign/shared/sign_outs/edit.html.erb`, identical UI to step 2)
5. User clicks `[sign-out]` again → POST `/sign/out` → `continue_acme_coordinated_logout`, advances
   `sign_cleared`, clears sign-side session, redirects via jump to
   `www.umaxica.app/oidc/logout?logout_challenge=…`
6. `Acme::App::Oidc::LogoutsController#show` (GET) — **renders confirmation form #3**
   (`SignOidcLogout#handle_logout_challenge_request` calls `render_oidc_end_session_confirmation` on
   GET)
7. User clicks `[sign-out]` a third time → POST → finalizes the transaction → redirects via jump →
   `/sign/out/complete` (final page)

Three of the seven steps render an interactive confirmation form. Only the **first** is a genuine
user-intent check; the other two are _coordination hops_ that must run in the browser because the
surfaces live on different hosts (cross-host cookies cannot be cleared server-to-server), but they
do not need user input. They render an `edit` template only because the controller actions
short-circuit on GET.

Relevant code:

- `app/controllers/sign/app/sign/outs_controller.rb:24` — `#edit` always renders the confirmation
  form, even when `params[:logout_challenge]` is present (mid-flow).
- `app/controllers/concerns/sign_oidc_logout.rb:49` — `handle_logout_challenge_request` on GET calls
  `render_oidc_end_session_confirmation` unconditionally.
- `app/views/sign/shared/sign_outs/edit.html.erb:8-12` and
  `app/views/acme/shared/sign_outs/edit.html.erb:8-12` — both render a manual submit form with
  `data: { turbo: false }`.
- State machine reference: `plans/active/logout-state-machine-implementation-plan.md`.

## Recommended approach

Make the intermediate coordination steps **non-interactive** — the user confirms once on the origin
surface, and the downstream hops auto-advance.

Two viable shapes (pick during review):

**A. Server-side auto-POST on GET (recommended).** When a coordination GET arrives with a valid
`logout_challenge` whose transaction is still `initiated` / `origin_cleared` / `sign_cleared` (i.e.
the user already authorized this transaction upstream), bypass
`render_oidc_end_session_confirmation` and run the same logic the POST branch runs
(`logout_current_session!`, `advance!`, `redirect_to_jump_url`). Authorization-equivalence is
provided by the `logout_challenge` being a single-use, unguessable token bound to the upstream actor
and session (`AcmeLogoutTransactionService.issue!` stores `actor_ref` + `session_ref`).

**B. Render an auto-submitting page (fallback).** Render an `edit`-style template whose `<form>`
submits itself with JS on load, plus a `<noscript>` button. Worse UX (extra paint, JS dependency,
CSP friction visible in the existing CSP violation reports for these pages) and does not reduce
roundtrips — only use if A is judged too risky for the security model.

Recommend **A**. The state machine already encodes single-use semantics (`expected_step` +
`completed_steps`); GET-driven advance is safe as long as we keep the CSRF/replay protections that
the challenge token already provides and we still reject reused/expired challenges.

### Files to modify

- `app/controllers/sign/app/sign/outs_controller.rb` — in `#edit`, if
  `params[:logout_challenge].present?` and the transaction is live and in an expected
  `sign_cleared`-eligible state, run the same body as `continue_acme_coordinated_logout` and
  redirect, instead of rendering. Keep the existing render for the no-challenge case (direct user
  navigation).
- `app/controllers/concerns/sign_oidc_logout.rb` — in `handle_logout_challenge_request`, on GET,
  when `@logout_transaction` is in an expected state, fall through to the existing advance/redirect
  code path instead of `render_oidc_end_session_confirmation`. Keep the confirmation render for the
  OIDC RP-initiated end-session flow (no challenge, post_logout_redirect_uri provided) — that one is
  a genuine consent step.
- `app/services/acme_logout_transaction_service.rb` — expose (if not already) a predicate like
  `safe_to_auto_advance?(expected_step:)` so both controllers share the same "is this a valid
  mid-flow coordination hop" check. Reuse existing `expected_step`/`completed_steps` accessors
  rather than introducing new state.

Do **not** change:

- `Acme::App::Sign::OutsController#edit` on `www.umaxica.app` — that is the genuine first user
  confirmation. It must keep rendering the form.
- The OIDC end-session confirmation path used by external RPs (no `logout_challenge` in our
  coordinated form, but an `id_token_hint` + `post_logout_redirect_uri`) — that flow needs explicit
  user consent per OIDC RP-Initiated Logout.

### Tests to add / update

- `test/controllers/sign/app/sign_outs_controller_test.rb` — add a case: GET `/sign/out/edit`
  **with** `logout_challenge` for a valid live transaction returns 303 to the next hop
  (`acme_oidc_logout_url`), advances the transaction to `sign_cleared`, and does **not** render the
  form. Existing case for GET without `logout_challenge` should still render.
- `test/controllers/acme/app/sign_outs_controller_test.rb` — the
  `Acme::App::Sign::OutsController#edit` path stays the same (still renders).
- `test/controllers/acme/com/oidc/logouts_controller_test.rb` and the matching `app` test — add a
  case: GET `/oidc/logout?logout_challenge=…` for an in-flight transaction auto-advances and
  redirects; expired/unknown challenges still render the completion page (existing behavior).
- Cover negative cases: replay (`completed_at` already set), expired (`expires_at < now`), wrong
  `expected_step` — all must fall back to the safe completion-render path, not advance.

## Verification

1. Start the app (`bin/dev` / `bin/rails s` + sign service on its host).
2. Sign in on `www.umaxica.app` (any path), then navigate to `/sign/out`.
3. Click `[sign-out]` **once**. Expect: one redirect chain through
   `id.umaxica.app/sign/out/edit?logout_challenge=…` →
   `www.umaxica.app/oidc/logout?logout_challenge=…` → `/sign/out/complete?ri=jp`, with no
   intermediate form rendered. Browser network tab should show 303s, not 200s with forms, for the
   two intermediate steps.
4. Inspect `acme_logout_transactions` for the new row: `status` should reach `finalized`,
   `completed_steps` should include `origin_cleared`, `sign_cleared`, `acme_cleared`.
5. Negative path: replay the intermediate URL after completion → expect the completion template, not
   a second logout cycle.
6. `bin/rails test test/controllers/sign/app/sign_outs_controller_test.rb \ test/controllers/acme/app/sign_outs_controller_test.rb \ test/controllers/acme/com/oidc/logouts_controller_test.rb \ test/controllers/acme/app/oidc/logouts_controller_test.rb`.
7. Broader regression: `bin/rails test test/controllers/sign test/controllers/acme`.
