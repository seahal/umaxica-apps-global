# Remove OIDC Front-Channel Logout and Harden Back-Channel Logout

## Context

The current branch ships both OIDC Back-Channel and Front-Channel Logout. The product/security
decision is to drop Front-Channel entirely and harden Back-Channel so a
forged-but-cryptographically-valid logout token cannot be accepted by the RP receiver.

Reasons:

- Front-Channel relies on browser iframe loads at logout time, which are unreliable (third-party
  cookie blocking, popup blockers, page transitions, ITP) and surface privacy/security questions
  this product does not want to answer.
- Back-Channel is server-to-server, signed, and replay-protected — the only mechanism we want for
  cross-RP logout propagation.
- Current codec accepts `sub`-only tokens and does not enforce UUID `sid`. The receiver enforces
  UUID at lookup time, so a non-UUID `sid` is "accepted but unmatchable" — silently ineffective.
  Hardening moves UUID enforcement and `sid`-required enforcement up to token validation so invalid
  tokens fail loudly with 400, not silently as a no-op.

Acme remains the OP. Sign and Core are RPs. Palm is untouched. `/oauth/revoke`, `/sso/logout`, and
`/sign/out` are untouched.

## Scope

### Route changes — remove front-channel only

`config/routes/sign.rb` (three surfaces — `app`, `com`, `org`) and `config/routes/core.rb` (three
surfaces — `app`, `com`, `org`) each contain a block:

```ruby
namespace :oidc do
  resource :backchannel_logout, only: :create, path: "backchannel_logout", controller: "backchannel_logouts"
  resource :frontchannel_logout, only: :show, path: "frontchannel_logout", controller: "frontchannel_logouts"
end
```

Delete the second line from all six occurrences. Keep `:backchannel_logout`. `config/routes/acme.rb`
and `config/routes/palm.rb` are unchanged.

### Service changes

**`app/services/oidc_logout_token_codec.rb`** — harden:

- Add `exp` claim to `encode`. Default lifetime `2.minutes` (short-lived, OIDC-spec-recommended).
  Add `expires_in:` kwarg so tests can override.
- `encode` must require non-blank `sid`. Drop the "sid or subject" allowance — raise `ArgumentError`
  when `sid` is blank. `subject` stays optional.
- `encode` must validate UUID format on `sid` (use `OidcRpSessionLogout::UUID_PATTERN`, moved to the
  codec or referenced as a shared constant — see below).
- `decode` must:
  - Add `exp` to `required_claims` (passed through to `JWT.decode`, which already verifies `exp` via
    `verify_iat: true` — also enable `verify_exp` is on by default in `ruby-jwt`).
  - In `validate_payload!`, require `sid` (raise `JWT::DecodeError, "sid required"` when blank, even
    if `sub` is present — drop the `sid or sub` allowance).
  - In `validate_payload!`, validate UUID format on `sid` (raise
    `JWT::DecodeError, "sid must be UUID"`).
- Replay guard, `nonce` rejection, `events` claim check, `typ`, `alg`, signature, `iss`, `aud`
  validation are kept as-is.

Move `UUID_PATTERN` from `OidcRpSessionLogout` to a single shared constant — preferred location:
keep it on `OidcRpSessionLogout` and reference `OidcRpSessionLogout::UUID_PATTERN` from the codec
(no new module needed; this keeps the value-object boundary intact).

**`app/services/oidc_discovery_document.rb`** — remove front-channel advertisement:

Delete:

```ruby
frontchannel_logout_supported: true,
frontchannel_logout_session_supported: true,
```

Keep `backchannel_logout_supported: true` and `backchannel_logout_session_supported: true`. Keep
`end_session_endpoint`.

**`app/services/oidc_client_registry.rb`** — remove front-channel registration, add session-required
flag:

- Drop `frontchannel_logout_uris` from the `VisitorAccount` `Data.define(...)` field list.
- Drop the `frontchannel_logout_uris` mapping in `find`.
- Drop the module method `frontchannel_logout_uris_for`.
- Simplify `logout_clients_for_resource_type` to test only `backchannel_logout_uris`.
- Drop the `frontchannel_logout_uris: build_logout_uris(...)` blocks from `sign-rp` and
  `core-next-rp`.
- Add `backchannel_logout_session_required: true` as a field on `VisitorAccount`. Default `false` in
  `find` for clients that do not declare it. Set `backchannel_logout_session_required: true` on
  `sign-rp` and `core-next-rp`. (This is documentary metadata — the codec already enforces `sid` at
  validation; the registry flag makes the policy explicit and discoverable.)

**`app/services/oidc_frontchannel_logout_urls.rb`** — DELETE the file. No callers remain after the
concern change below.

### Concern changes

**`app/controllers/concerns/sign_oidc_logout.rb`** (despite the name, included by Acme OP logouts
controllers):

- In `perform_oidc_end_session_logout`, remove the middle branch:
  ```ruby
  elsif (@frontchannel_logout_urls = frontchannel_logout_urls(result)).present?
    @oidc_logout_completed_path = oidc_logout_completed_path(ri: result.legacy_ri || params[:ri])
    render :frontchannel, status: :ok
  ```
  The remaining flow becomes: if `post_logout_redirect_uri` present → redirect to it; else →
  redirect to `oidc_logout_completed_path`.
- Delete the `frontchannel_logout_urls` private method.

**`app/controllers/concerns/oidc_rp_logout_receiver.rb`** — remove front-channel receiver:

- Delete `handle_oidc_frontchannel_logout`.
- Delete `valid_frontchannel_issuer?`.

The remaining `handle_oidc_backchannel_logout` is already POST-only by virtue of the route. It
already returns 400 on `result.success? == false`, and the codec now rejects non-UUID `sid`, so the
receiver inherits that behavior. `OidcRpSessionLogout` continues to be idempotent for an unknown
UUID `sid` (returns `false`, no DB mutation) — the receiver still responds 200, which satisfies the
spec requirement that "already logged out" is a success.

### Files to delete

- `app/services/oidc_frontchannel_logout_urls.rb`
- `app/controllers/sign/app/oidc/frontchannel_logouts_controller.rb`
- `app/controllers/sign/com/oidc/frontchannel_logouts_controller.rb`
- `app/controllers/sign/org/oidc/frontchannel_logouts_controller.rb`
- `app/controllers/core/app/oidc/frontchannel_logouts_controller.rb`
- `app/controllers/core/com/oidc/frontchannel_logouts_controller.rb`
- `app/controllers/core/org/oidc/frontchannel_logouts_controller.rb`
- `app/views/acme/app/oidc/logouts/frontchannel.html.erb`
- `app/views/acme/com/oidc/logouts/frontchannel.html.erb`
- `app/views/acme/org/oidc/logouts/frontchannel.html.erb`

### Test changes

**`test/services/oidc/discovery_document_test.rb`** — flip the front-channel assertions:

Replace `assert_equal true, document[:frontchannel_logout_supported]` (and the session variant) with
`assert_not document.key?(:frontchannel_logout_supported)` (and session variant). Keep back-channel
assertions.

**`test/services/oidc/client_registry_test.rb`** — drop front-channel coverage, add
session-required:

- Delete the `sign.frontchannel_logout_uris` and `core.frontchannel_logout_uris` assertions (current
  lines ~75/77).
- Add `assert_equal true, OidcClientRegistry.find!("sign-rp").backchannel_logout_session_required`
  and the same for `core-next-rp`. Add a negative assertion for a content client (e.g. `docs_app`)
  that the default is `false`.

**`test/services/oidc/logout_token_codec_test.rb`** — extend hardening coverage:

Update existing `encode` calls to pass an explicit UUID `sid` (they already do —
`SecureRandom.uuid`). Add tests:

- `rejects missing sid at encode` (passing `sid: nil` raises ArgumentError — currently raises only
  if both sid and sub are blank; after change it raises when sid is blank).
- `rejects non-UUID sid at encode` (raises ArgumentError).
- `rejects sub-only token at decode` — forge a payload with `sub` present and `sid` absent, sign
  with the test key, expect `result.success? == false`.
- `rejects non-UUID sid at decode` — forge a payload with `sid: "not-a-uuid"`, sign, expect
  `success? == false`.
- `rejects missing exp at decode` — forge payload without `exp`, expect failure.
- `rejects expired token at decode` — `expires_in: -60` (or `iat` far in past), expect failure.
- `rejects nonce present` — already implicitly covered by `assert_not result.payload.key?("nonce")`
  on round-trip; add a forged-payload test that puts `nonce` in and expects failure.
- `rejects wrong events claim` — payload with `events: { "http://other" => {} }` → failure.

For forged-payload tests, sign with `JitSecurityJwtKeyring.encode(payload, issuer_id: ...)` directly
to bypass the encode-side guards.

**`test/controllers/oidc/rp_logout_receivers_test.rb`** — drop front-channel, expand back-channel:

- Delete `test "front-channel receiver validates issuer"`.
- Add `test "back-channel receiver rejects non-UUID sid with 400"` — forge a token with
  `sid: "not-a-uuid"` via direct keyring encode, POST it, expect `:bad_request`.
- Add `test "back-channel receiver is idempotent for unknown UUID sid"` — encode a valid token with
  a fresh random UUID that does not match any token row, POST it, expect `:success`.
- Keep "back-channel receiver accepts valid logout token idempotently" and "back-channel receiver
  rejects invalid logout token" — they already cover the happy path and signature-invalid case.

**`test/controllers/acme/{app,com,org}/oidc/logouts_controller_test.rb`** — drop front-channel
expectations from the no-redirect path:

- In the "valid id_token_hint POST without `post_logout_redirect_uri`" test, replace
  `assert_includes response.body, "/oidc/frontchannel_logout"` with `assert_response :see_other` and
  `assert_redirected_to <oidc_logout_completed path or pattern>`. Keep the
  `assert_enqueued_jobs 2, only: OidcBackchannelLogoutDeliveryJob` assertion.
- The "valid `post_logout_redirect_uri`" test already asserts no front-channel URL in body — keep
  the assertion as a regression guard (it still passes; nothing renders that view).

Apply the same change to all three surface tests.

**`test/controllers/sign/route_naming_test.rb`** — drop front-channel route, add negative assertion:

- Delete the `assert_routing` for `GET /oidc/frontchannel_logout`.
- Add:
  `assert_raises(ActionController::RoutingError) { Rails.application.routes.recognize_path("/oidc/frontchannel_logout", method: :get) }`
  under each surface host context, or use `assert_recognizes` negative form.
- Keep the back-channel `POST /oidc/backchannel_logout` assertion.

### Out of scope (explicitly unchanged)

- `app/controllers/concerns/oidc_callback.rb` — login callback, no logout coupling.
- `config/routes/acme.rb` — `:oidc/:logout` (show, create) stays.
- `config/routes/palm.rb`.
- `/oauth/revoke`, `/sso/logout`, `/sign/out`.
- DB schema. The `oidc_sid` column on token models is already present and is the lookup key for
  back-channel revocation. No migration needed.
- Background job `OidcBackchannelLogoutDeliveryJob` — already implemented; not changed by this work.

## Verification

All commands run inside Podman. The Rails service in `compose.yaml` is `core`.

```sh
podman compose ps

# Confirm no frontchannel routes remain anywhere.
podman compose exec core bin/rails routes | grep -Ei 'oidc|logout|frontchannel|backchannel|revoke|sign_out|sso'

# Codec hardening
podman compose exec core env PARALLEL_WORKERS=1 bin/rails test test/services/oidc/logout_token_codec_test.rb

# Discovery + registry
podman compose exec core env PARALLEL_WORKERS=1 bin/rails test test/services/oidc/discovery_document_test.rb
podman compose exec core env PARALLEL_WORKERS=1 bin/rails test test/services/oidc/client_registry_test.rb

# RP receiver (all six surfaces in one integration test)
podman compose exec core env PARALLEL_WORKERS=1 bin/rails test test/controllers/oidc/rp_logout_receivers_test.rb

# Acme OP logout controllers
podman compose exec core env PARALLEL_WORKERS=1 bin/rails test test/controllers/acme/app/oidc/logouts_controller_test.rb
podman compose exec core env PARALLEL_WORKERS=1 bin/rails test test/controllers/acme/com/oidc/logouts_controller_test.rb
podman compose exec core env PARALLEL_WORKERS=1 bin/rails test test/controllers/acme/org/oidc/logouts_controller_test.rb

# Sign route naming (frontchannel route removed; backchannel kept)
podman compose exec core env PARALLEL_WORKERS=1 bin/rails test test/controllers/sign/route_naming_test.rb

# Broader OIDC suite to catch any indirect break
podman compose exec core env PARALLEL_WORKERS=1 bin/rails test test/services/oidc test/controllers/acme test/controllers/sign test/controllers/core test/controllers/oidc

# Brakeman — fail-loudly: if bin/brakeman absent, stop and report.
podman compose exec core bin/brakeman || podman compose exec core bundle exec brakeman
```

### Acceptance

- `bin/rails routes | grep frontchannel` returns nothing.
- All six discovery/registry/codec/receiver/Acme/route tests pass with `PARALLEL_WORKERS=1`.
- Brakeman reports no new high-confidence warning in:
  - `app/controllers/concerns/oidc_rp_logout_receiver.rb`
  - `app/services/oidc_logout_token_codec.rb`
  - `app/jobs/oidc_backchannel_logout_delivery_job.rb`
  - `config/routes/sign.rb`
  - `config/routes/core.rb`
- Logout-token round-trip with UUID `sid` + `exp` succeeds; sub-only, non-UUID sid, missing `sid`,
  missing `exp`, expired `exp`, replayed `jti`, nonce, wrong audience, wrong issuer, wrong events
  all return `success: false` with `error: "invalid_logout_token"`.
- Acme `/oidc/logout` POST (id_token_hint, no `post_logout_redirect_uri`) → 303 redirect to
  `oidc_logout_completed_path`, enqueues 2 back-channel delivery jobs, body does not contain
  `/oidc/frontchannel_logout`.

## Notes

- Test file layout follows the existing pattern: the consolidated
  `test/controllers/oidc/rp_logout_receivers_test.rb` covers all six RP surfaces; new tests are
  added there rather than splitting into per-surface files.
- The `exp` default of 2 minutes is short-lived enough to bound replay window without breaking job
  retry behavior (the delivery job has 2s/3s timeouts and no retry; tokens are minted per-delivery
  in `OidcBackchannelLogoutNotifier`).
- Removing the `frontchannel_logout_uris` field from `VisitorAccount` is a small surface-area
  change; grep for `frontchannel_logout_uris` before the change to confirm there are no callers
  beyond the registry, the deleted service, and tests.
