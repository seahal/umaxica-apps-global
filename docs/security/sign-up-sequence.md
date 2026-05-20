# Sign-Up Sequence

This document records the current sign-up routing sequence for the `app` and `com` sign surfaces,
and the operator acquisition/lifecycle routing sequence for `org`. It is intentionally descriptive:
it captures the behavior that exists today so a future sign-up state machine can replace the
scattered session/controller state without changing route intent by accident.

`org` is excluded from the six app/com user-facing sign-up routes below. It has
invitation/provisioning entry points and operator lifecycle requests, not a normal end-user sign-up
flow.

## Current Route Inventory

`app` has four sign-up entry paths:

1. Email sign-up.
2. Telephone sign-up.
3. Google social sign-up.
4. Apple social sign-up.

`com` has two sign-up entry paths:

1. Email sign-up.
2. Telephone sign-up.

`org` has two operator acquisition/lifecycle paths:

1. External candidate inquiry.
2. Operator lifecycle request.

All six paths currently bypass a dedicated sign-up birthdate gate. The `birthdate` value can be
shown later from configuration, but the sign-up sequence does not require or persist it today.

## Common Post-Finalization Handoff

All `app` and target `com` sign-up paths share the same post-finalization routing rule:

1. Complete sign-up finalization.
2. Enter the existing sign-in boundary in the same Rails action/request.
3. The sign-in boundary evaluates `/sign/in/guardrail` before session issuance.
4. If sign-in guardrail does not block, issue the authenticated session.
5. Continue to `/sign/in/checkpoint` and `/dashboard`.
6. If a safe `rt` return path is present, jump there after dashboard sequence handling.

The sign-up finalization and sign-in boundaries must not redirect, render, or perform an HTTP reload
between each other. Route selection belongs to the post-finalization handoff after the sign-in
boundary has either stopped at guardrail or issued the authenticated session.

## Signed-In Actor Re-entry

A signed-in actor must not start a new sign-up or sign-in sequence without first signing out.
Attempting to enter registration or login while already signed in is an abnormal request.

The server must reject that request with a status code and a plain-text message. It must not
redirect to dashboard, continue a return path, create a new registration sequence, or sign the actor
out on their behalf.

## Guardrail, Checkpoint, And Dashboard

`/sign/up/guardrail` is the sign-up stop point for cases where the current sign-up sequence must not
continue. It is distinct from `/sign/up/checkpoint`:

- Guardrail blocks continuation and returns only plain text.
- Checkpoint collects or clears required setup before finalization.

`/sign/in/guardrail` is also part of the common post-finalization handoff. It is evaluated before
session issuance. If it blocks after durable sign-up completion, that is a sign-in failure domain;
it must not delete completed account data.

Guardrail, checkpoint, and dashboard are sequence participants whose required content can grow or
disappear over time. The sign-up state machine decides when the current sequence is allowed to
evaluate each participant.

Each participant evaluates an ordered stack of requirement items for the current sign-up or
post-finalization sign-in sequence. The sequence advances only when the current participant's stack
is empty or every required stack item is cleared.

Expected participant behavior:

- Guardrail: if the stack is empty, advance without displaying a page. If the stack has any blocking
  item, stop the attempt with plain text. No redirect is performed.
- Checkpoint: if the stack is empty, advance without displaying a page. If the stack has any
  blocking item, keep the actor at checkpoint until all required setup is cleared.
- Dashboard: if the sequence dashboard stack is empty, continue to the safe `rt` return path or
  default destination. If the stack has items, display them after sign-in. Reaching dashboard means
  the actor has completed the normal `AAL1` sign-in boundary and can behave as a signed-in actor.

`/dashboard` also remains an ordinary authenticated page. Only the post-finalization sequence
dashboard participant consumes the preserved `rt` handoff; ordinary direct dashboard access must not
turn a query parameter into a post-auth continuation.

For example, telephone sign-up checkpoint can contain separate birthdate, passkey, and passcode
requirements. The account must not finalize until all three items are cleared. Adding a future
requirement should add a checkpoint item, not introduce a new route between checkpoint and
finalization.

## Reference Shape: Email Sign-Up

Email sign-up is the cleanest current route and should be treated as the reference when the sign-up
state machine is introduced.

### App Email

Expected state-machine path:

- Entry: `GET /sign/up/email/new`
  - Start or resume the app sign-up sequence.
  - The sequence is still before contact submission.
  - Backtracking rules should allow returning here only while no irreversible contact verification
    has completed.

- Email submission: `POST /sign/up/email`
  - Validate Turnstile and email params.
  - Create or resume pending email verification.
  - Move the sequence to the email OTP step.

- OTP form: `GET /sign/up/email/edit`
  - Show the pass-code form only while the sequence is waiting for email OTP.
  - Reject direct access when the sequence is missing, expired, or no longer at the OTP step.

- OTP submission: `PATCH /sign/up/email`
  - Verify the submitted pass code.
  - Existing-account sign-up attempts should leave the sign-up sequence and return to sign-in.
  - New-account sign-up should move the sequence toward guardrail/checkpoint without allowing a
    return to email editing.

- Sign-up guardrail: `GET /sign/up/guardrail`
  - This is the sign-up stop point for sequence-level rejection such as policy blocks, retry
    cooldowns, or other non-continuable registration states.
  - It returns plain text and does not redirect.
  - If no guardrail content is required, the sequence advances to checkpoint.

- Sign-up checkpoint: `GET /sign/up/checkpoint`
  - This is a sign-up sequence checkpoint, not the current private `/sign/in/checkpoint`.
  - For email sign-up, the checkpoint must require birthdate.
  - Birthdate collection happens inside the checkpoint.
  - The checkpoint validates the exact `YYYY-MM-DD` text form.
  - The checkpoint rejects future values.
  - The checkpoint persists the encrypted birthdate.
  - Once birthdate is accepted, the checkpoint can complete.
  - If no other checkpoint content is required after birthdate, the route can continue immediately.

- Account finalization
  - Allowed only when email OTP and checkpoint birthdate are complete.
  - Replace the current `create_user_and_login` shape with two internal boundaries:
    - `sign_up` finalizes the pending sign-up actor and required sign-up artifacts.
    - the existing sign-in boundary evaluates guardrail and then issues the authenticated session
      only if guardrail does not block.
  - Both boundaries run inside the same Rails action/request.
  - Neither boundary redirects, renders, reloads through HTTP, or chooses the final route.
  - Promote the pending `Client`.
  - Create `rp_account` when missing.
  - Write the sign-up audit entry.
  - Save the verified email state.
  - Enter the sign-in boundary with `auth_method: "email"`; session issuance happens only after
    sign-in guardrail passes.
  - If sign-up finalization fails, treat it as sign-up failure recovery.
  - If sign-in/session issuance fails after durable sign-up completion, treat it as sign-in failure
    handling and do not delete the completed account.

- Dashboard sequence: `GET /dashboard`
  - Current route helper: `sign_app_dashboard_path`.
  - This step is also bypassable by `continue_dashboard_sequence_without_content!` when no dashboard
    sequence content is required.
  - The common post-finalization handoff applies: after sign-in guardrail passes, session issuance,
    checkpoint, and dashboard handling, continue to the safe `rt` return path when present.

- Post-auth handoff: `complete_update_and_redirect`
  - The controller-level completion hook should hand off into the sequence instead of deciding the
    final route by itself.

Current implementation path:

- Entry: `GET /sign/up/email/new`
  - `Sign::App::Up::EmailsController#new`
  - Builds an empty `ClientEmail`.
  - No pending client is created yet.

- Email submission: `POST /sign/up/email`
  - `Sign::App::Up::EmailsController#create`
  - Validates Turnstile.
  - Permits `user_email.raw_address`, `user_email.address`, `user_email.confirm_policy`,
    `user_email.promotional`, and `user_email.notifiable`.
  - Calls `initiate_email_verification!`.
  - Creates or resumes the pending sign-up email verification.
  - Stores registration progress in session.
  - Redirects to `GET /sign/up/email/edit`.

- OTP form: `GET /sign/up/email/edit`
  - `Sign::App::Up::EmailsController#edit`
  - Loads `current_registration_email`.
  - Rejects the request and resets the flow if the pending email session is missing, expired, or
    mismatched.
  - Renders the pass-code form when the session is valid.

- OTP submission: `PATCH /sign/up/email`
  - `Sign::App::Up::EmailsController#update`
  - Requires `user_email.pass_code`.
  - Calls `process_verification_code`.
  - Existing-account sign-up attempts are redirected back to sign-in instead of creating a new
    account.
  - New-account sign-up calls `complete_email_verification!` and then `create_user_and_login`.

- Account finalization: current `create_user_and_login`
  - Uses the pending `Client` from the verified `ClientEmail`.
  - Promotes the client to `ClientStatus::VERIFIED_WITH_SIGN_UP`.
  - Creates `rp_account` when missing.
  - Writes the sign-up audit entry.
  - Saves the verified email.
  - Logs in the client with `auth_method: "email"`.

- Post-auth handoff: `complete_update_and_redirect`
  - Advances the local email flow session state.
  - Creates the welcome bulletin.
  - Calls `redirect_to_sign_in_sequence!`.
  - Target behavior is that guardrail is evaluated before session issuance.
  - In the current implementation, the actor reaches `/sign/in/checkpoint` if checkpoint content
    exists.
  - Otherwise, or after checkpoint completion, the actor continues to dashboard and then the safe
    `rt` return path when present.

Current missing gate:

- No sign-up checkpoint birthdate requirement is inserted between OTP success and the post-auth
  handoff.
- No birthdate value is permitted by the email sign-up controller.
- Account finalization currently happens during OTP completion, before any birthdate or sign-up
  checkpoint step.

### Com Email

Target state-machine path:

- Entry: `GET /sign/up/email/new`
  - Start or resume the com sign-up sequence.
  - The sequence is still before contact submission.
  - Backtracking rules should allow returning here only while no irreversible contact verification
    has completed.

- Email submission: `POST /sign/up/email`
  - Validate Turnstile and email params.
  - Create or resume pending email verification.
  - Move the sequence to the email OTP step.

- OTP form: `GET /sign/up/email/edit`
  - Show the pass-code form only while the sequence is waiting for email OTP.
  - Reject direct access when the sequence is missing, expired, or no longer at the OTP step.

- OTP submission: `PATCH /sign/up/email`
  - Verify the submitted pass code.
  - Existing-account sign-up attempts should leave the sign-up sequence and return to sign-in.
  - New-account sign-up should move the sequence toward guardrail/checkpoint without allowing a
    return to email editing.

- Sign-up guardrail: `GET /sign/up/guardrail`
  - This is the sign-up stop point for sequence-level rejection such as policy blocks, retry
    cooldowns, or other non-continuable registration states.
  - It returns plain text and does not redirect.
  - If no guardrail content is required, the sequence advances to checkpoint.

- Sign-up checkpoint: `GET /sign/up/checkpoint`
  - This is a sign-up sequence checkpoint, not the current private `/sign/in/checkpoint`.
  - For com email sign-up, the checkpoint must require birthdate.
  - Birthdate collection happens inside the checkpoint.
  - The checkpoint validates the exact `YYYY-MM-DD` text form.
  - The checkpoint rejects future values.
  - The checkpoint persists the encrypted birthdate.
  - Once birthdate is accepted, the checkpoint can complete.
  - If no other checkpoint content is required after birthdate, the route can continue immediately.

- Account finalization
  - Allowed only when email OTP and checkpoint birthdate are complete.
  - Use the same two-boundary shape as app email: sign-up finalization first, then the existing
    sign-in boundary inside the same Rails action/request.
  - Do not redirect, render, or perform an HTTP reload between sign-up finalization and sign-in.
  - Promote or finalize the pending `Visitor`.
  - Create `rp_account` when missing.
  - Write the sign-up audit entry.
  - Save the verified email state.
  - Enter the sign-in boundary with `auth_method: "email"`; session issuance happens only after
    sign-in guardrail passes.
  - Sign-up finalization failure belongs to sign-up failure recovery.
  - Sign-in/session issuance failure after durable sign-up completion belongs to sign-in failure
    handling and must not delete completed account data.

- Dashboard sequence: `GET /dashboard`
  - Current route helper: `sign_com_dashboard_path`.
  - The common post-finalization handoff applies: after sign-in guardrail passes, session issuance,
    checkpoint, and dashboard handling, continue to the safe `rt` return path when present.

Current path:

1. `GET /sign/up/email/new` renders the email sign-up form.
2. `POST /sign/up/email` validates Turnstile, validates email params, creates or resumes pending
   visitor email verification, stores pending registration state in session, and redirects to edit.
3. `GET /sign/up/email/edit` renders the OTP form when the pending email session is valid.
4. `PATCH /sign/up/email` validates the OTP.
5. OTP success marks the `VisitorEmail` as `VERIFIED_WITH_SIGN_UP`.
6. The visitor account row is created if needed.
7. A sign-up audit entry is written.
8. The visitor is logged in.
9. A welcome bulletin is requested through the shared helper.
10. The flow calls the sign-in post-authentication sequence.
11. Target behavior is that guardrail is evaluated before session issuance.
12. In the current implementation, the actor reaches `/sign/in/checkpoint` if checkpoint content
    exists.
13. Otherwise, or after checkpoint completion, the actor continues to dashboard and then the safe
    `rt` return path when present.

## App Telephone

App telephone sign-up verifies telephone ownership first, then moves into the sign-up checkpoint.
The checkpoint owns required setup such as passkey registration; the telephone OTP route should not
branch into a separate passkey-registration route before the checkpoint.

Expected state-machine path:

- Entry: `GET /sign/up/telephone/new`
  - Start or resume the app sign-up sequence.
  - The sequence is still before telephone submission.

- Telephone submission: `POST /sign/up/telephone`
  - Validate Turnstile and telephone params.
  - Create or resume pending telephone verification.
  - Create the pending `Client` when needed.
  - Move the sequence to the SMS OTP step.

- SMS OTP form: `GET /sign/up/telephone/edit`
  - Show the pass-code form only while the sequence is waiting for SMS OTP.
  - Reject direct access when the sequence is missing, expired, or no longer at the SMS OTP step.

- SMS OTP submission: `PATCH /sign/up/telephone`
  - Verify the submitted pass code.
  - Mark the telephone as `VERIFIED_WITH_SIGN_UP`.
  - Check whether the pending client already has an active passkey.
  - Move the sequence toward guardrail/checkpoint without allowing a return to telephone editing.

- Sign-up guardrail: `GET /sign/up/guardrail`
  - This is the sign-up stop point for sequence-level rejection such as policy blocks, retry
    cooldowns, or other non-continuable registration states.
  - It returns plain text and does not redirect.
  - If no guardrail content is required, the sequence advances to checkpoint.

- Sign-up checkpoint: `GET /sign/up/checkpoint`
  - This checkpoint owns all required post-contact setup before account finalization.
  - For SMS sign-up, the checkpoint must require all of:
    - accepted birthdate;
    - at least one active passkey for the pending client;
    - at least one active sign-in-capable passcode for the pending client.
  - If any requirement is missing, the checkpoint remains incomplete and the actor cannot continue
    to account finalization.
  - The checkpoint can render both setup tasks on one page or route to dedicated setup substeps, but
    the sequence state should remain `CHECKPOINT_PENDING` until both are complete.

- Birthdate setup requirement
  - Birthdate collection happens inside `/sign/up/checkpoint`.
  - The checkpoint validates the exact `YYYY-MM-DD` text form.
  - The checkpoint rejects future values.
  - The checkpoint persists the encrypted birthdate and marks the birthdate requirement as cleared.

- Passkey setup requirement
  - Passkey registration happens from the checkpoint when the pending client has no active passkey.
  - The existing `/sign/up/telephone/passkey_registration` implementation is the current mechanism,
    but the state-machine route should model it as checkpoint-owned setup.
  - Future route shape can be generalized to `/sign/up/passkey` if the same checkpoint is shared by
    email, telephone, and social sign-up.
  - Completion creates a `ClientPasskey` for the pending client and marks the passkey requirement as
    cleared.

- Passcode setup requirement
  - Use the existing model/service layer: `ClientSecret` and `ClientSecrets::Create`.
  - Do not reuse the configuration controller directly; it is written for an already-authenticated
    actor and step-up flow.
  - Generate the raw passcode server-side, show it once, persist only the digest, and mark the
    passcode requirement as cleared after the user confirms storage.
  - The passcode should be sign-in capable, active, and attached to the pending client before
    account finalization.

- Account finalization
  - Allowed only when telephone OTP, birthdate, passkey setup, and passcode setup are all complete.
  - Use the same two-boundary shape as email: sign-up finalization first, then the existing sign-in
    boundary inside the same Rails action/request.
  - Do not redirect, render, or perform an HTTP reload between sign-up finalization and sign-in.
  - Promote the pending `Client`.
  - Create `rp_account` when missing.
  - Write the sign-up audit entry.
  - Enter the sign-in boundary with `auth_method: "telephone"`; session issuance happens only after
    sign-in guardrail passes.
  - Sign-up finalization failure belongs to sign-up failure recovery.
  - Sign-in/session issuance failure after durable sign-up completion belongs to sign-in failure
    handling and must not delete completed account data.

- Dashboard sequence: `GET /dashboard`
  - Current route helper: `sign_app_dashboard_path`.
  - This step is bypassable by `continue_dashboard_sequence_without_content!` when no dashboard
    sequence content is required.
  - The common post-finalization handoff applies: after sign-in guardrail passes, session issuance,
    checkpoint, and dashboard handling, continue to the safe `rt` return path when present.

Current path:

1. `GET /sign/up/telephone/new` renders the telephone form and clears the telephone registration
   session key.
2. `POST /sign/up/telephone` validates Turnstile and telephone params, creates a pending `Client`
   and pending `ClientTelephone`, stores telephone registration state in session, and redirects to
   edit.
3. `GET /sign/up/telephone/edit` renders the OTP form when the registration session is valid.
4. `PATCH /sign/up/telephone` validates the OTP.
5. OTP success marks the telephone as `VERIFIED_WITH_SIGN_UP`.
6. The current implementation checks whether the pending client already has an active passkey.
7. If a passkey exists, the client can currently be promoted and signed in immediately.
8. If no passkey exists, the current implementation redirects to
   `/sign/up/telephone/passkey_registration`.

Target state-machine path:

1. `PATCH /sign/up/telephone` validates the OTP.
2. OTP success marks the telephone as `VERIFIED_WITH_SIGN_UP`.
3. The flow checks whether the pending client already has an active passkey.
4. The flow moves through `GET /sign/up/guardrail` when guardrail content is required.
5. The flow moves to `GET /sign/up/checkpoint`.
6. The checkpoint blocks account finalization until birthdate, passkey, and passcode requirements
   are all cleared.
7. Only after the checkpoint is complete, the client is promoted, the account row is created, audit
   is written, and the existing sign-in boundary may issue the session after guardrail passes.

## App Social

App social sign-up uses the same social entry and callback as social sign-in. A missing provider
identity creates a new client account.

### App Google

Expected state-machine path:

- Entry: `GET /sign/up/new` or `GET /sign/up`
  - User chooses Google from the app sign-up surface.
  - The sequence starts before leaving the application for the provider.

- Social start: `POST /social/auth/google_app/continue`
  - Store sign-up intent, provider, region, sanitized `rt`, and callback state in the server-side
    session.
  - Redirect to `/auth/google_app`.
  - Do not encode application routing decisions into OAuth `state`; keep OAuth `state` dedicated to
    callback integrity.

- Provider redirect: Google
  - Google handles authentication and consent.
  - The application is outside the local sequence until the callback returns.

- Social callback: `GET /auth/google_app/callback`
  - Verify the social callback request.
  - Validate the stored social auth state.
  - Normalize the provider to Google.
  - If the Google identity already belongs to an account, leave sign-up and continue as sign-in.
  - If the identity is new, create the pending `Client` and link the Google identity.
  - Move the sign-up sequence toward guardrail/checkpoint.

- Sign-up guardrail: `GET /sign/up/guardrail`
  - This is the sign-up stop point for sequence-level rejection such as policy blocks, retry
    cooldowns, or other non-continuable registration states.
  - It returns plain text and does not redirect.
  - If no guardrail content is required, the sequence advances to checkpoint.

- Sign-up checkpoint: `GET /sign/up/checkpoint`
  - For Google sign-up, the checkpoint must require birthdate.
  - Birthdate collection happens inside `/sign/up/checkpoint`.
  - The checkpoint validates the exact `YYYY-MM-DD` text form.
  - The checkpoint rejects future values.
  - The checkpoint persists the encrypted birthdate and marks the birthdate requirement as cleared.
  - Google social login counts as an AAL1 sign-in method, but not as an AAL2 step-up method.
  - Passkey or passcode setup can be added here later by policy, but the current required Google
    sign-up checkpoint requirement is birthdate.

- Account finalization
  - Allowed only when Google callback identity handling and checkpoint birthdate are complete.
  - Use the same two-boundary shape as email: social sign-up finalization first, then the existing
    social sign-in boundary inside the same Rails action/request.
  - Do not redirect, render, or perform an HTTP reload between sign-up finalization and sign-in.
  - Ensure the linked Google identity is active.
  - Write the social sign-up audit entry.
  - Enter the sign-in boundary with `auth_method: "social"` and provider context; session issuance
    happens only after sign-in guardrail passes.
  - Sign-up finalization failure belongs to sign-up failure recovery.
  - Sign-in/session issuance failure after durable sign-up completion belongs to sign-in failure
    handling and must not delete completed account data.

- Dashboard sequence: `GET /dashboard`
  - Current route helper: `sign_app_dashboard_path`.
  - This step is bypassable by `continue_dashboard_sequence_without_content!` when no dashboard
    sequence content is required.
  - The common post-finalization handoff applies: after sign-in guardrail passes, session issuance,
    checkpoint, and dashboard handling, continue to the safe `rt` return path when present.

### App Apple

Expected state-machine path:

- Entry: `GET /sign/up/new` or `GET /sign/up`
  - User chooses Apple from the app sign-up surface.
  - The sequence starts before leaving the application for the provider.
  - Apple sign-up is app-only; `com` and `org` must not offer it.

- Social start: `POST /social/auth/apple/continue`
  - Store sign-up intent, provider, region, sanitized `rt`, and callback state in the server-side
    session.
  - Redirect to `/auth/apple`.
  - Do not encode application routing decisions into OAuth `state`; keep OAuth `state` dedicated to
    callback integrity.

- Provider redirect: Apple
  - Apple handles authentication and consent.
  - The application is outside the local sequence until the callback returns.

- Social callback: `POST /auth/apple/callback`
  - Verify the social callback request.
  - Validate the stored social auth state.
  - Normalize the provider to Apple.
  - If the Apple identity already belongs to an account, leave sign-up and continue as sign-in.
  - If the identity is new, create the pending `Client` and link the Apple identity.
  - Move the sign-up sequence toward guardrail/checkpoint.

- Sign-up guardrail: `GET /sign/up/guardrail`
  - This is the sign-up stop point for sequence-level rejection such as policy blocks, retry
    cooldowns, or other non-continuable registration states.
  - It returns plain text and does not redirect.
  - If no guardrail content is required, the sequence advances to checkpoint.

- Sign-up checkpoint: `GET /sign/up/checkpoint`
  - For Apple sign-up, the checkpoint must require birthdate.
  - Birthdate collection happens inside `/sign/up/checkpoint`.
  - The checkpoint validates the exact `YYYY-MM-DD` text form.
  - The checkpoint rejects future values.
  - The checkpoint persists the encrypted birthdate and marks the birthdate requirement as cleared.
  - Apple social login counts as an AAL1 sign-in method, but not as an AAL2 step-up method.
  - Passkey or passcode setup can be added here later by policy, but the current required Apple
    sign-up checkpoint requirement is birthdate.

- Account finalization
  - Allowed only when Apple callback identity handling and checkpoint birthdate are complete.
  - Use the same two-boundary shape as email: social sign-up finalization first, then the existing
    social sign-in boundary inside the same Rails action/request.
  - Do not redirect, render, or perform an HTTP reload between sign-up finalization and sign-in.
  - Ensure the linked Apple identity is active.
  - Write the social sign-up audit entry.
  - Enter the sign-in boundary with `auth_method: "social"` and provider context; session issuance
    happens only after sign-in guardrail passes.
  - Sign-up finalization failure belongs to sign-up failure recovery.
  - Sign-in/session issuance failure after durable sign-up completion belongs to sign-in failure
    handling and must not delete completed account data.

- Dashboard sequence: `GET /dashboard`
  - Current route helper: `sign_app_dashboard_path`.
  - This step is bypassable by `continue_dashboard_sequence_without_content!` when no dashboard
    sequence content is required.
  - The common post-finalization handoff applies: after sign-in guardrail passes, session issuance,
    checkpoint, and dashboard handling, continue to the safe `rt` return path when present.

Current path:

1. `POST /social/auth/:provider/continue` stores social intent, provider, entry, region, and
   sanitized `rt` in session.
2. The controller redirects to `/auth/:provider`.
3. The provider redirects back to `/auth/:provider/callback`.
4. The callback verifies the social callback request and validates social auth session state.
5. A missing social identity creates a new `Client` with `UNVERIFIED_WITH_SIGN_UP` status defaults.
6. The social identity is created and linked.
7. A social sign-up audit entry is written.
8. The client is signed in through the normal social login path.
9. New and existing accounts both call the sign-in post-authentication sequence.
10. Target behavior is that guardrail is evaluated before session issuance, then the actor reaches
    checkpoint/dashboard/`rt` according to the sign-in sequence.

## Com Telephone

Com telephone sign-up should be rebuilt to match the app telephone sequence shape. It verifies
telephone ownership first, then moves into the sign-up checkpoint. The checkpoint owns required
setup such as passkey and passcode registration; the telephone OTP route should not finalize the
account directly.

Target state-machine path:

- Entry: `GET /sign/up/telephone/new`
  - Start or resume the com sign-up sequence.
  - The sequence is still before telephone submission.

- Telephone submission: `POST /sign/up/telephone`
  - Validate Turnstile and telephone params.
  - Create or resume pending telephone verification.
  - Create the pending `Visitor` when needed.
  - Move the sequence to the SMS OTP step.

- SMS OTP form: `GET /sign/up/telephone/edit`
  - Show the pass-code form only while the sequence is waiting for SMS OTP.
  - Reject direct access when the sequence is missing, expired, or no longer at the SMS OTP step.

- SMS OTP submission: `PATCH /sign/up/telephone`
  - Verify the submitted pass code.
  - Mark the telephone as `VERIFIED_WITH_SIGN_UP`.
  - Check whether the pending visitor already has an active passkey.
  - Move the sequence toward guardrail/checkpoint without allowing a return to telephone editing.

- Sign-up guardrail: `GET /sign/up/guardrail`
  - This is the sign-up stop point for sequence-level rejection such as policy blocks, retry
    cooldowns, or other non-continuable registration states.
  - It returns plain text and does not redirect.
  - If no guardrail content is required, the sequence advances to checkpoint.

- Sign-up checkpoint: `GET /sign/up/checkpoint`
  - This checkpoint owns all required post-contact setup before account finalization.
  - For com telephone sign-up, the checkpoint must require all of:
    - accepted birthdate;
    - at least one active passkey for the pending visitor;
    - at least one active sign-in-capable passcode for the pending visitor.
  - If any requirement is missing, the checkpoint remains incomplete and the actor cannot continue
    to account finalization.
  - Passkey and passcode setup are checkpoint-owned setup steps for the pending visitor.

- Birthdate setup requirement
  - Birthdate collection happens inside `/sign/up/checkpoint`.
  - The checkpoint validates the exact `YYYY-MM-DD` text form.
  - The checkpoint rejects future values.
  - The checkpoint persists the encrypted birthdate and marks the birthdate requirement as cleared.

- Passkey setup requirement
  - Passkey registration happens from the checkpoint when the pending visitor has no active passkey.
  - Do not reuse the configuration controller directly; it is written for an already-authenticated
    actor and step-up flow.
  - Completion creates a `VisitorPasskey` for the pending visitor and marks the passkey requirement
    as cleared.

- Passcode setup requirement
  - Use the existing model/service layer shape for `VisitorSecret`.
  - Do not reuse the configuration controller directly; it is written for an already-authenticated
    actor and step-up flow.
  - Generate the raw passcode server-side, show it once, persist only the digest, and mark the
    passcode requirement as cleared after the user confirms storage.
  - The passcode should be sign-in capable, active, and attached to the pending visitor before
    account finalization.

- Account finalization
  - Allowed only when telephone OTP, birthdate, passkey setup, and passcode setup are all complete.
  - Use the same two-boundary shape as app telephone: sign-up finalization first, then the existing
    sign-in boundary inside the same Rails action/request.
  - Do not redirect, render, or perform an HTTP reload between sign-up finalization and sign-in.
  - Promote or finalize the pending `Visitor`.
  - Create `rp_account` when missing.
  - Write the sign-up audit entry.
  - Enter the sign-in boundary with `auth_method: "telephone"`; session issuance happens only after
    sign-in guardrail passes.
  - Sign-up finalization failure belongs to sign-up failure recovery.
  - Sign-in/session issuance failure after durable sign-up completion belongs to sign-in failure
    handling and must not delete completed account data.

- Dashboard sequence: `GET /dashboard`
  - Current route helper: `sign_com_dashboard_path`.
  - The common post-finalization handoff applies: after sign-in guardrail passes, session issuance,
    checkpoint, and dashboard handling, continue to the safe `rt` return path when present.

Current path:

1. `GET /sign/up/telephone/new` renders the telephone form and clears the telephone registration
   session key.
2. `POST /sign/up/telephone` validates Turnstile and telephone params, creates a pending `Visitor`
   and pending `VisitorTelephone`, stores telephone registration state in session, and redirects to
   edit.
3. `GET /sign/up/telephone/edit` renders the OTP form when the registration session is valid.
4. `PATCH /sign/up/telephone` validates the OTP.
5. OTP success marks the telephone as `VERIFIED_WITH_SIGN_UP`.
6. The visitor account row is created if needed.
7. A sign-up audit entry is written.
8. The visitor is logged in.
9. The controller redirects to `root_path`.

Unlike app email, com email, app telephone completion, and app social completion, com telephone does
not currently call the shared sign-in post-authentication sequence after login.

Target state-machine path:

1. `PATCH /sign/up/telephone` validates the OTP.
2. OTP success marks the telephone as `VERIFIED_WITH_SIGN_UP`.
3. The flow checks whether the pending visitor already has an active passkey.
4. The flow moves through `GET /sign/up/guardrail` when guardrail content is required.
5. The flow moves to `GET /sign/up/checkpoint`.
6. The checkpoint blocks account finalization until birthdate, passkey, and passcode requirements
   are all cleared.
7. Only after the checkpoint is complete, the visitor is finalized, the account row is created,
   audit is written, and the existing sign-in boundary may issue the session after guardrail passes.

## Org Operator Acquisition And Lifecycle

Org is not an app/com-style public sign-up surface. A public org request must not create an
`Operator` directly. Operator creation, mutation, and withdrawal are controlled lifecycle events.

### External Candidate Inquiry

Target path:

- Public entry: `GET /sign/up/new`
  - Render an org sign-up unavailable or recruiting guidance page.
  - Do not create an `Operator`.
  - Do not create an authenticated org session.
  - Link the external candidate to the com/corporate contact or recruiting intake surface.

- Optional guardrail: `GET /sign/up/guardrail`
  - This is only for an org acquisition sequence that must stop with a plain-text message.
  - It must not become public self-service operator registration.
  - Direct access without valid sequence state must be rejected.

- Com/corporate intake
  - The candidate submits an inquiry, contact request, or future direct-message intake on the com
    side.
  - The intake record is reviewed operationally.
  - If the candidate should become an operator, an existing operator starts an operator lifecycle
    request.

Current path:

1. `GET /sign/up/new` is handled by `Sign::Org::UpsController#new`.
2. The view renders recruiting guidance.
3. The recruiting link currently points to the corporate/com root.
4. No `Operator` is created.
5. No org authentication session is issued.

### Operator Lifecycle Request

Target path:

- Existing operator sign-in
  - The actor must already be an org operator.
  - The actor completes the normal org sign-in sequence.

- Lifecycle request form: `GET /configuration/operator_lifecycle_requests/new`
  - Used for operator create, update, withdrawal, or related lifecycle actions.
  - The request records the intended action, target operator or target email, organization, role,
    and reason.

- Lifecycle request submission: `POST /configuration/operator_lifecycle_requests`
  - Require AAL2 step-up with scope `operator_lifecycle`.
  - Create an `OperatorLifecycleRequest`.
  - Do not execute privileged lifecycle changes directly from an unauthenticated public route.

- Optional lifecycle guardrail
  - Lifecycle-specific stops can use the same guardrail semantics: plain text, no redirect, and no
    lifecycle mutation when the sequence state is invalid.

- Approval / rejection / execution
  - Approved requests move through the configured approval and execution controllers.
  - Execution creates, updates, or withdraws the target operator.
  - The target operator later uses normal org sign-in and credential setup paths.

Current path:

1. An authenticated operator opens `GET /configuration/operator_lifecycle_requests/new`.
2. `POST /configuration/operator_lifecycle_requests` requires step-up scope `operator_lifecycle`.
3. The request is persisted as an `OperatorLifecycleRequest`.
4. Approval, rejection, and execution are handled under
   `/configuration/operator_lifecycle_requests/:id/...`.

### Org Invitation Routes

Current route shape includes `/sign/up/invitations` for controlled invitation acceptance. Legacy
`/sign/up/invitations/emails` routes were removed because they were an incomplete public
operator-registration path.

Target decision:

- Keep invitation acceptance only when it is tied to a pre-approved operator lifecycle request.
- Do not expose email or social public self-registration routes for org operators.

## Current Gaps To Preserve For Refactor Planning

- The six sign-up routes do not have a dedicated birthdate collection step.
- Post-sign-up routing is mostly routed through the sign-in post-authentication sequence, but com
  telephone currently redirects directly to `root_path`.
- The current implementation stores progress across credential-specific session keys, pending
  principal/contact rows, and controller-local checks.
- The six sign-up routes do not have a dedicated sign-up guardrail step.
- App telephone sign-up has an additional incomplete-registration window between telephone OTP
  success and required passkey registration completion.
- Com sign-up should be rebuilt to follow the app email/telephone sequence shape rather than
  incrementally patching the current weaker email/telephone split.
- Org public sign-up should remain a candidate inquiry handoff, not an operator-creation route.
- Org operator creation, mutation, and withdrawal should remain lifecycle requests from an existing
  authenticated operator with AAL2 step-up.
- A future state machine should make one-way transitions explicit and should define where guardrail,
  birthdate collection, checkpoint, dashboard, and `rt` continuation sit.
