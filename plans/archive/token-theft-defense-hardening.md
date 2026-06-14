# Token-Theft Defense Hardening (DBSC-preferred / idle-timeout / IP-anomaly)

## Status

Implemented and archived on 2026-06-14.

Current code already contains the first implementation pass for DBSC preferred registration,
idle-timeout enforcement, and IP-network anomaly detection. Do not treat the original "planned, not
yet implemented" audit text as current state.

Implemented evidence in the current tree:

- Browser-login tokens are issued `LEGACY` + `PENDING` for DBSC-capable registration paths, with
  explicit fallback to `NOTHING` when registration is not completed within the grace window.
- Per-request activity tracking and idle-timeout enforcement exist through
  `AuthenticationCurrentResourceResolver`, `AuthenticationBase#refresh_idle_allowed?`, and
  `SecurityTokenLifetimes`.
- `last_network_hmac` exists on client/operator/visitor device sessions, backed by additive ticket
  migrations and structure dumps.
- `OccurrenceHmac.network_hmac` / `network_prefix` exist and are covered by tests.
- Refresh-side network change detection emits `ip_change_detected`, updates the stored network HMAC,
  and feeds the feature-flagged `SignRiskEngine` rule.

Final cleanup completed:

- Focused verification passed for the DB-free token-theft checks listed below.
- `plans/backlog/session-token-hardening-implementation.md` and
  `adr/session-token-hardening-baseline.md` were updated so idle timeout and IP-network anomaly
  handling are no longer described as unimplemented in the current tree.
- `IP_ANOMALY_REVOKE_ENABLED` remains a feature flag; non-local rollout still needs operational
  monitoring before enablement.

## Context

Session/access-token theft bypasses MFA via two paths: **AiTM phishing** (mitigated by
FIDO2/WebAuthn origin binding) and **infostealer malware stealing live cookies** (mitigated by
device-bound sessions / DBSC). An audit mapped the article's structural recommendations to this
repo. Dispositions were decided with the owner.

### Already satisfied (no action)

- WebAuthn origin / RP-ID binding, one-shot challenges —
  `app/controllers/concerns/sign_webauthn.rb:23-70,113-166,236-269`.
- DBSC present (binding, JWS proof verification, refresh-time enforcement) —
  `app/models/concerns/dbsc_bindable.rb`,
  `app/services/dbsc_{registration,verification}_service.rb`,
  `app/controllers/concerns/authentication_base.rb:1219-1314`.
- DPoP sender-constrained tokens, **already enforced on refresh** when `dpop_jkt` present —
  `authentication_base.rb:1189-1217`; OIDC issuance `oidc_token_exchange_service.rb:144,165`;
  per-request `oidc_access_token_authenticator.rb:58-74`.
- Refresh rotation + reuse/replay detection → risk score 100 → revoke;
  `app/services/sign_risk_{engine,emitter,enforcer}.rb`.
- Cookie hardening (`secure`, `httponly`, `__Host-`, partitioned; auth cookies `SameSite=Strict`);
  one-time recovery codes (`app/models/client_secret_credential.rb:128-135`); session caps.

### Dispositions

- **#1 Phishing-resistance is per-credential, not per-path** (AAL1 accepts email_otp/secret/social;
  AAL2 step-up accepts email_otp/totp alongside passkey;
  `phishing_resistant_methods = aal2 & [:passkey]`,
  `app/services/authentication_credential_inventory.rb:126-152`): **ACCEPTED as-is.** TOTP + email
  OTP are intentionally retained as required alternative factors. Documentation only.
- **#2 DBSC pending registration default**: **IMPLEMENTED — Phase A.** Browser-login tokens now
  enter a `LEGACY` + `PENDING` registration window and downgrade to an explicit `NOTHING` fallback
  if the challenge expires without proof.
- **#3 Idle timeout**: **IMPLEMENTED — Phase B.** Per-request activity writes and refresh/access
  idle gates use the configured surface windows.
- **#4 IP-network anomaly revocation**: **IMPLEMENTED FOR SIGNAL + FEATURE-FLAGGED ENFORCEMENT —
  Phase C.** Network HMAC changes emit `ip_change_detected`; `SignRiskEngine` scores the event as
  revoke-worthy only when `IP_ANOMALY_REVOKE_ENABLED` or the matching config flag is enabled.
- **#5 Session cookie `SameSite=Lax`** (`config/initializers/session_store.rb:18`): **NON-ISSUE** —
  Rails framework constraint; auth cookies are already Strict.

Note: an earlier exploration claim of a "step-up flag not persisted FIXME at
`app/lib/sign/risk/enforcer.rb:39`" is **false** (no such file; real enforcer is
`app/services/sign_risk_enforcer.rb`, which persists via token/freshness revocation).

### Related decision material

- `adr/device-session-dbsc-device-id-boundary.md` — DBSC-as-primary-binding migration path (#2).
- `adr/session-token-hardening-baseline.md` — idle expiry and IP-network anomaly language was
  updated during archive cleanup; see `adr/ip-anomaly-session-revocation.md`.
- `adr/token-lifetime-policy-by-surface.md` + backlog impl plan — per-surface TTL split is **out of
  scope** here (idle-only chosen).
- `plans/backlog/session-token-hardening-implementation.md`,
  `plans/backlog/dbsc-performance-improvement.md`.

## Phase A — DBSC preferred-when-supported + bearer DPoP

Reality: `Sec-Session-Registration` is already offered to unbound tokens
(`authentication_base.rb:1356-1367`) and capable browsers already upgrade to `DBSC/ACTIVE`. The gap
is that the "awaiting registration" state is untracked and untimed.

- **A1 DONE** `default_dbsc_token_attributes`: for browser-login tokens issue
  `binding_method = LEGACY`, `dbsc_status = PENDING` (registration offered). Keep OIDC
  token-endpoint tokens at `NOTHING`.
- **A2 DONE (critical, must not lock out non-DBSC browsers)** `legacy_unbound_refresh_allowed?`
  includes a **grace downgrade**: when `LEGACY` + `PENDING` and the registration challenge has
  expired (no proof within `DBSC_COOKIE_TTL` = 10 min), set `dbsc_status = NOTHING` and allow the
  refresh as an explicit fallback session. Capable browsers that registered are `DBSC/ACTIVE` and
  flow through `refresh_dbsc_allowed?` unchanged.
- **A3 PARTIAL** DPoP-on-refresh is already fail-closed; retain/verify regression tests: jkt-bound
  token refused without/with wrong DPoP proof; jkt-bound access token refused when used as plain
  Bearer.
- Tests: PENDING→NOTHING grace downgrade for client/operator/visitor; extend
  `test/controllers/dbsc_controller_test.rb`, `test/services/dpop/*`,
  `test/services/oidc/access_token_authenticator_dpop_test.rb`.

## Phase B — Idle timeout (idle only; absolute caps unchanged)

- **B1 DONE** Throttled per-request activity write: update `last_used_at` / `last_seen_at` in the
  per-request resolver (`authentication_current_resource_resolver.rb` / `load_from_token`
  `authentication_base.rb:1396-1433`) via `update_column`, only when stale > ~60s.
- **B2 DONE** `SecurityTokenLifetimes` defines client/app **8h**, operator/org **30m**, and visitor
  **8h** idle windows. `AuthenticationBase#refresh_idle_allowed?` denies stale refresh attempts and
  emits `refresh_failed` reason `idle_timeout`; access-token resolution also returns
  `:idle_timeout`.
- Tests near `test/services/security/token_lifetimes_test.rb` + auth refresh suites.

## Phase C — IP/ASN-change anomaly → hard revoke (feature-flagged)

Owner decision: **hard-revoke** on anomaly. Data source: **lightweight IP-network change** (no
external GeoIP). This contradicts `adr/session-token-hardening-baseline.md` §7 — see and land
`adr/ip-anomaly-session-revocation.md` (supersedes §7).

- **C1 DONE** Add nullable, reversible column `last_network_hmac` to device-session tables (no
  destructive ops). Store HMAC of the coarse network (**/24 IPv4, /48 IPv6**) via an
  `OccurrenceHmac` network helper; update alongside `last_seen_at`.
- **C2 DONE** Emit `ip_change_detected` from the refresh path (`sign_risk_emitter.rb`) when the
  request network HMAC differs from the stored one within the risk window. Coarse network tolerates
  NAT/IP churn; only network-level change counts.
- **C3 DONE / FEATURE-FLAGGED** `SignRiskEngine` rule + `SignRiskEnforcer`: `ip_change_detected`
  scores ≥100 → `revoke!` only when the feature flag is enabled. **Feature-flag** it
  (`IP_ANOMALY_REVOKE_ENABLED`, default OFF outside prod) and document the mobile-network
  false-positive tradeoff. Roll out with monitoring.
- **C4 REMAINING** Update `plans/backlog/session-token-hardening-implementation.md` and any stable
  docs that still describe these gaps as unimplemented.
- Tests: extend `test/services/sign/risk/{engine,emitter,enforcer}_test.rb` — network change →
  revoke under flag; no revoke for in-network churn or flag off.

## Sequencing & safety

- Phases A/B/C have landed in the current tree; future work should be follow-up cleanup rather than
  reimplementation.
- Refresh/revocation changes are security-sensitive: keep failure-path tests before broadening the
  feature flag rollout.
- Re-read each cited `file:line` before editing; this file is a snapshot and line numbers drift.

## Verification

Focused checks passed for the current implementation where the files were available:

```bash
bin/rails test test/controllers/concerns/authentication/base_coverage_test.rb \
               test/controllers/concerns/authentication/current_resource_resolver_test.rb \
               test/models/concerns/occurrence/hmac_test.rb \
               test/services/security/token_lifetimes_test.rb \
               test/services/sign/risk/engine_test.rb
```

The focused token-theft subset that does not require stale parallel DB clones passed with 23 runs,
51 assertions, 0 failures, 0 errors:

```bash
bin/rails test test/models/concerns/occurrence/hmac_test.rb \
               test/services/security/token_lifetimes_test.rb \
               test/services/sign/risk/engine_test.rb
```

Run broader authentication/security coverage before enabling `IP_ANOMALY_REVOKE_ENABLED` in any
non-local environment.
