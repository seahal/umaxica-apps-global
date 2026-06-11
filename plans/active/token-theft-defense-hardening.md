# Token-Theft Defense Hardening (DBSC-preferred / idle-timeout / IP-anomaly)

## Status

Active — planned, not yet implemented. Captures an implementation-side gap audit of this platform
against session/access-token theft (AiTM phishing and infostealer malware) and the agreed
remediation. Implementation deferred for capacity; this file is the handoff.

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
- **#2 DBSC default unbound** (`default_dbsc_token_attributes` issues LEGACY/NOTHING,
  `authentication_base.rb:1761-1781`): **FIX — Phase A.**
- **#3 No idle timeout** (`last_used_at` recorded only on refresh, not enforced): **FIX — Phase B.**
- **#4 No location/anomaly revocation** (IP only HMAC-logged, `occurrence_hmac.rb:35-42`): **FIX —
  Phase C (hard-revoke; see ADR conflict).**
- **#5 Session cookie `SameSite=Lax`** (`config/initializers/session_store.rb:18`): **NON-ISSUE** —
  Rails framework constraint; auth cookies are already Strict.

Note: an earlier exploration claim of a "step-up flag not persisted FIXME at
`app/lib/sign/risk/enforcer.rb:39`" is **false** (no such file; real enforcer is
`app/services/sign_risk_enforcer.rb`, which persists via token/freshness revocation).

### Related decision material

- `adr/device-session-dbsc-device-id-boundary.md` — DBSC-as-primary-binding migration path (#2).
- `adr/session-token-hardening-baseline.md` — idle expiry listed as not-yet-implemented (#3); §7
  forbids IP/UA-only hard invalidation — **conflicts with #4**, see
  `adr/ip-anomaly-session-revocation.md`.
- `adr/token-lifetime-policy-by-surface.md` + backlog impl plan — per-surface TTL split is **out of
  scope** here (idle-only chosen).
- `plans/backlog/session-token-hardening-implementation.md`,
  `plans/backlog/dbsc-performance-improvement.md`.

## Phase A — DBSC preferred-when-supported + bearer DPoP

Reality: `Sec-Session-Registration` is already offered to unbound tokens
(`authentication_base.rb:1356-1367`) and capable browsers already upgrade to `DBSC/ACTIVE`. The gap
is that the "awaiting registration" state is untracked and untimed.

- **A1** `default_dbsc_token_attributes` (`:1761-1781`): for browser-login tokens issue
  `binding_method = LEGACY`, `dbsc_status = PENDING` (registration offered). Keep OIDC
  token-endpoint tokens at `NOTHING`.
- **A2 (critical, must not lock out non-DBSC browsers)** `legacy_unbound_refresh_allowed?`
  (`:1244-1258`) currently rejects any non-`NOTHING` status. Add a **grace downgrade**: when
  `LEGACY` + `PENDING` and the registration challenge has expired (no proof within `DBSC_COOKIE_TTL`
  = 10 min), set `dbsc_status = NOTHING` and allow the refresh as an explicit fallback session.
  Capable browsers that registered are `DBSC/ACTIVE` and flow through `refresh_dbsc_allowed?`
  unchanged.
- **A3** DPoP-on-refresh is already fail-closed; add regression tests: jkt-bound token refused
  without/with wrong DPoP proof; jkt-bound access token refused when used as plain Bearer.
- Tests: PENDING→NOTHING grace downgrade for client/operator/visitor; extend
  `test/controllers/dbsc_controller_test.rb`, `test/services/dpop/*`,
  `test/services/oidc/access_token_authenticator_dpop_test.rb`.

## Phase B — Idle timeout (idle only; absolute caps unchanged)

- **B1** Throttled per-request activity write: update `last_used_at` / `last_seen_at` in the
  per-request resolver (`authentication_current_resource_resolver.rb` / `load_from_token`
  `authentication_base.rb:1396-1433`) via `update_column`, only when stale > ~60s.
- **B2** Add `IDLE_TTL` to `SecurityTokenLifetimes` (`app/services/security_token_lifetimes.rb`);
  proposed defaults client/app **8h**, operator/org **30m**, visitor **8h** (tunable). Mirror into
  `AuthenticationBase`. Deny refresh when `now - last_used_at > IDLE_TTL` (new
  `refresh_idle_allowed?` ANDed at `:521-531`), emit `refresh_failed` reason `idle_timeout`; also
  reject stale access tokens in `currently_usable?` (`token_status_management.rb:68-74`) so an idle
  session can't ride a live 1h access JWT.
- Tests near `test/services/security/token_lifetimes_test.rb` + auth refresh suites.

## Phase C — IP/ASN-change anomaly → hard revoke (feature-flagged)

Owner decision: **hard-revoke** on anomaly. Data source: **lightweight IP-network change** (no
external GeoIP). This contradicts `adr/session-token-hardening-baseline.md` §7 — see and land
`adr/ip-anomaly-session-revocation.md` (supersedes §7).

- **C1** Add nullable, reversible column `last_network_hmac` to device-session tables (no
  destructive ops). Store HMAC of the coarse network (**/24 IPv4, /48 IPv6**) via an
  `OccurrenceHmac` network helper; update alongside `last_seen_at`.
  - DONE: `OccurrenceHmac.network_hmac` / `network_prefix` added
    (`app/models/concerns/occurrence_hmac.rb`) with tests
    (`test/models/concerns/occurrence/hmac_test.rb`, green). Remaining: migration for
    `last_network_hmac`, wiring the per-session update, emit + enforce (C2/C3).
- **C2** Emit `ip_change_detected` from the refresh path (`sign_risk_emitter.rb`) when the request
  network HMAC differs from the stored one within the risk window. Coarse network tolerates NAT/IP
  churn; only network-level change counts.
- **C3** `SignRiskEngine` rule + `SignRiskEnforcer`: `ip_change_detected` scores ≥100 → `revoke!`.
  **Feature-flag** it (`IP_ANOMALY_REVOKE_ENABLED`, default OFF outside prod) and document the
  mobile-network false-positive tradeoff. Roll out with monitoring.
- **C4** Update `plans/backlog/session-token-hardening-implementation.md` once implemented.
- Tests: extend `test/services/sign/risk/{engine,emitter,enforcer}_test.rb` — network change →
  revoke under flag; no revoke for in-network churn or flag off.

## Sequencing & safety

- Phases A/B/C independent; land in order, each its own commit on a topic branch.
- Refresh/revocation changes are security-sensitive: write the failure-path test first.
- C1 migration: additive, nullable, reversible only; `bin/rails db:verify_no_schema_drift` after.
- Re-read each cited `file:line` before editing (this file is a snapshot; line numbers drift).
