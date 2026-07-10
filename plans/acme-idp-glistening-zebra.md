# OIDC SSO Bug: Acme IdP Session Not Reused by RP

**Plan ID:** acme-idp-glistening-zebra  
**Status:** Draft

## Context

When a user is already signed in to Acme (the Authorization Server) and then navigates to an
auth-required page on a Relying Party (Sign, Core, Base, Palm), the RP initiates an OIDC
Authorization Code flow. The expected behavior is that Acme recognizes the existing session and
issues an authorization code directly, without showing the sign-in screen again.

Reported symptom: the RP reaches Acme's `/oauth/authorize` via `jump.umaxica.net` rather than via a
direct same-site redirect. Because `jump.umaxica.net` is a different site, the browser blocks Acme's
`SameSite=Strict` `__Host-access` cookie. Acme sees no session cookie, treats the request as
unauthenticated, and creates a pending `OidcAuthorizationTransaction` with `actor_ref: nil` —
forcing the user to sign in again.

## Investigation Findings

### Bug 1 — `oidc_port` uses the RP's port, not Acme's port (confirmed code defect)

`app/controllers/concerns/oidc_sso_initiator.rb:129`

```ruby
def oidc_port
  [80, 443].include?(request.port) ? nil : request.port
end
```

`oidc_port` is passed to `URI::Generic.build(port: oidc_port, ...)` to construct the Acme
authorization URL. It uses `request.port` — the **RP's** port — not Acme's port. In any multi-port
environment (e.g., Sign on `:3001`, Acme on `:3000`), the Acme URL ends up targeting the wrong
server. In production both services use port 443 so `oidc_port` resolves to `nil` and the bug is
latent; in dev/staging with per-service ports the URL is wrong. The same method is reused for
`oidc_token_url`.

### Bug 2 — `oidc_acme_scheme` localhost detection fails with port in host string (confirmed code defect)

`app/controllers/concerns/oidc_sso_initiator.rb:133`

```ruby
def oidc_acme_scheme
  return "http" if !request.ssl? && oidc_acme_host.to_s.end_with?(".localhost")
  "https"
end
```

If `oidc_acme_host` ever contains a port suffix (e.g., `"www.app.localhost:3001"`), the
`end_with?(".localhost")` check fails and the method returns `"https"` instead of `"http"`. This
would also cause `URI::Generic.build(host: oidc_acme_host, ...)` to raise
`URI::InvalidComponentError` because `host:` cannot contain colons, so the two bugs compound.
Normalizing the host string in `oidc_sso_initiator.rb` before use prevents both.

### Bug 3 — `same_site_oidc_authorization_url?` check 3 host-comparison mismatch under certain ENV formats

`app/controllers/concerns/oidc_sso_initiator.rb:65`

```ruby
return false unless CommonRedirect.normalize_host(uri.host) == CommonRedirect.normalize_host(oidc_acme_host)
```

`uri.host` (extracted by Ruby's `URI.parse`) always strips the port. `oidc_acme_host` is taken
directly from `ENV.fetch("ACME_SERVICE_URL", ...)`. If that ENV var is set to `"host:port"` format,
`normalize_host` leaves the port in the string (because `URI.parse("host:port")` treats it as
`scheme:opaque`, not `host:port`), causing a mismatch and a silent fallback to
`redirect_to_jump_url`. The fix for Bug 2 (extracting host-only from `oidc_acme_host`) eliminates
this path as well.

### Bug 4 — `same_site_oidc_authorization_url?` has no diagnostic logging

When any of the 7 guards returns `false`, the fallback to `redirect_to_jump_url` is silent. Without
log output, determining which guard fires in a given environment requires guesswork. Adding
structured logging before the `redirect_to_jump_url` call makes the failure visible.

### Missing coverage — no SSO success test exists for any RP

`test/integration/oidc_rp_browser_flow_test.rb`

Every existing integration test starts unauthenticated. None covers the scenario: _"Acme session
cookie present → RP initiates OIDC → Acme issues code directly (no ceremony)"_.

The test helper `jump_rt_url_from_location` is transparent for non-jump locations, so existing tests
pass whether or not a direct redirect is used — they do not assert the redirect path.

## Security Constraints (Non-negotiable)

These must be preserved throughout all changes:

- Do not accept Acme tokens as RP tokens
- Do not share tokens between RPs
- Do not remove issuer, host, or surface validation
- Do not skip state, nonce, or PKCE verification
- Do not allow arbitrary return URLs or open redirects
- Do not allow login CSRF or authorization code reuse
- Do not break refresh token rotation or revocation

## Proposed Changes

### 1. Introduce `oidc_acme_host_only` and `oidc_acme_port` helpers in `OidcSsoInitiator`

File: `app/controllers/concerns/oidc_sso_initiator.rb`

Add two private helpers:

```ruby
# Returns the bare hostname for the Acme AS, stripping any port that may be
# present in oidc_acme_host (e.g. from ENV vars using "host:port" format).
def oidc_acme_host_only
  host_str = oidc_acme_host.to_s
  # Prepend "//" so URI.parse treats "host:port" as authority, not scheme:opaque.
  uri = URI.parse("//#{host_str}")
  uri.host.presence || host_str.split(":").first
rescue URI::InvalidURIError
  host_str.split(":").first
end

# Returns the port for the Acme AS. In development the static client store always
# registers redirect URIs on port 3000; mirror that convention here. In production
# and on public hosts the standard port (nil) is used.
def oidc_acme_port
  return nil unless oidc_acme_host_only.to_s.end_with?(".localhost")
  3000
end
```

Replace all uses of `oidc_acme_host` in URI construction with `oidc_acme_host_only`, and replace
`oidc_port` with `oidc_acme_port`:

- `oidc_authorization_url`: `host: oidc_acme_host_only, port: oidc_acme_port`
- `oidc_token_url`: same substitution
- `oidc_acme_scheme`: change `end_with?(".localhost")` guard to use `oidc_acme_host_only`

```ruby
def oidc_acme_scheme
  return "http" if !request.ssl? && oidc_acme_host_only.to_s.end_with?(".localhost")
  "https"
end
```

- `same_site_oidc_authorization_url?` check 3: compare against `oidc_acme_host_only` to ensure both
  sides strip port before comparison.

```ruby
return false unless CommonRedirect.normalize_host(uri.host) == CommonRedirect.normalize_host(oidc_acme_host_only)
```

Keep the existing `oidc_port` method and rename it `oidc_rp_port` so callers that legitimately need
the RP's own port (if any) are not silently broken. `oidc_acme_port` becomes the only port used in
Acme-targeted URL construction.

### 2. Add diagnostic logging before the jump fallback

File: `app/controllers/concerns/oidc_sso_initiator.rb`

In `redirect_to_oidc_authorization_url`, log which path is taken so failures are visible in
production and dev without code changes:

```ruby
def redirect_to_oidc_authorization_url(url, **)
  if same_site_oidc_authorization_url?(url)
    Rails.logger.info(JitLogEvent.format("oidc.sso.initiator.direct_redirect", host: request.host))
    return redirect_to(url, allow_other_host: true, **)
  end

  Rails.logger.info(JitLogEvent.format("oidc.sso.initiator.jump_redirect", host: request.host, url: url.to_s.truncate(120)))
  redirect_to_jump_url(url, preserve_query_keys: ["redirect_uri"], **)
end
```

Do not log the full authorization URL (it contains `state`, `nonce`, `code_challenge`). Truncating
to 120 characters retains the scheme+host+path for diagnosis while avoiding leaking PKCE material in
most cases. If stricter log hygiene is needed, log only `request.host` and a boolean
`same_site: true/false`.

### 3. Add SSO integration tests per RP

File (extend): `test/integration/oidc_rp_browser_flow_test.rb` or a new
`test/integration/oidc_sso_already_logged_in_test.rb`

Add one test per RP surface verifying the happy path:

**Pattern** (apply to Sign, Core, Base, Acme-own):

```
Given: a valid Acme access-token cookie for a known actor
When:  RP's auth-required endpoint is called (or /oidc/authorization is called)
Then:
  - Response is a redirect
  - redirect location is directly to the RP's /oidc/callback (NOT through jump.umaxica.net)
    OR the location IS a jump URL whose destination is the RP /oidc/callback (if jump is legitimately needed for that RP)
  - The redirect carries a code parameter and the original state
  - No OidcAuthorizationTransaction with actor_ref=nil is created
```

Use `with_acme_oidc_client_key` (already in test helpers) and inject an Acme session token via
`set_auth_cookie` or equivalent. Follow the pattern in the existing
`"acme app browser flow reaches Acme token exchange without stubbing OP"` test for how to set up the
Acme session and call `/oauth/authorize` with an active cookie.

Each RP test must assert:

- `assert_response :redirect`
- The redirect destination eventually reaches `/oidc/callback?code=...&state=...`
- The code can be exchanged via `OidcRpTokenClient` and yields a valid ID token

**Security tests to add** (in `test/controllers/concerns/oidc/sso_initiator_test.rb` or same
integration file):

- State mismatch → `InvalidCallbackState` → cleared session, 422
- PKCE verifier mismatch → token exchange fails
- Authorization code reuse → second exchange fails
- Expired login_challenge → `bad_request` on resume
- `redirect_to_jump_url` is NOT called when `same_site_oidc_authorization_url?` returns true (use
  `assert_no_redirect_to_jump` helper or mock)

**Cookie/redirect tests:**

- Direct redirect is used (not jump) when RP and Acme share the same registrable domain
- Jump redirect is used when RP and Acme are on different registrable domains

## Files Changed

| File                                                                                                   | Change                                                                                                                                           |
| ------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `app/controllers/concerns/oidc_sso_initiator.rb`                                                       | Add `oidc_acme_host_only`, `oidc_acme_port`; fix `oidc_acme_scheme`; fix check #3 in `same_site_oidc_authorization_url?`; add diagnostic logging |
| `test/integration/oidc_sso_already_logged_in_test.rb` (new) or extended `oidc_rp_browser_flow_test.rb` | SSO success tests per RP, security tests, cookie/redirect path tests                                                                             |
| `test/controllers/concerns/oidc/sso_initiator_test.rb`                                                 | Tests for `oidc_acme_host_only` and `oidc_acme_port` edge cases                                                                                  |

No changes to routing, authorization pipelines, token issuance logic, or cross-RP boundaries.

## Verification

Run narrowest tests first:

```bash
bin/rails test test/controllers/concerns/oidc/sso_initiator_test.rb
bin/rails test test/integration/oidc_rp_browser_flow_test.rb
bin/rails test test/integration/oidc_sso_already_logged_in_test.rb   # new file
```

Then broader coverage:

```bash
bin/rails test test/integration/core_rp_browser_flow_test.rb
bin/rails test test/integration/base_rp_browser_flow_test.rb
bin/rails test test/integration/base_palm_auth_entrypoints_test.rb
```

End-to-end verification (manual or with a browser test harness):

1. Sign in to Acme directly (visit `www.app.localhost/sign/in`, complete login).
2. In the same browser, visit a page on Sign (`id.app.localhost/dashboard`).
3. Expect: browser redirected to Sign's callback with `?code=...&state=...`, no sign-in screen.
4. Confirm in Sign's logs: `oidc.sso.initiator.direct_redirect` (not `jump_redirect`).
5. Confirm: no `OidcAuthorizationTransaction` with `actor_ref: nil` exists in DB.

## Open Questions

1. **Production ENV format**: If `ACME_SERVICE_URL` contains scheme or port in production/staging
   (e.g., `"https://www.umaxica.app"` or `"www.umaxica.app:443"`), the existing code would crash at
   `URI::Generic.build`. Confirm the actual ENV format before deploying; the fix handles both
   bare-hostname and `host:port` formats safely.

2. **`issue_authorization_code!` also uses `redirect_to_jump_url`**:
   `Acme::App::Oauth::AuthorizationsController#issue_authorization_code!` uses jump to send the
   authorization code back to the RP callback. For same-site RPs this is unnecessary overhead (RP
   session cookies are SameSite=Lax and survive the jump hop). This is not causing the current bug
   but warrants a follow-up task.

3. **Palm (iOS/Android)**: Uses custom-scheme redirect URIs (`umaxica://`, `com.umaxica.app:/`).
   Same-site logic is irrelevant for these. The OIDC PKCE flow works via the OS URL scheme. No
   changes needed for Palm.
