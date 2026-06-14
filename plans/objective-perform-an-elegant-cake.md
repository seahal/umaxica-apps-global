# Architecture Review — Authentication, Authorization, Token, Session, Logout & Cookie Model

> **Type:** Design review and gap analysis. **No code, routes, or config are changed by this
> document.** **Authoring stance:** The objective grants greenfield authority ("prefer destructive
> simplification, reject unnecessary complexity, do not preserve historical compatibility unless
> strictly required"). I treat the objective as authoritative (decision-priority #1: explicit user
> instruction) and flag every conflict with currently-accepted ADRs in §0. Recommendations are
> opinionated by request.

---

## Context — why this review exists

The target direction is a clean separation of concerns: **Acme is the only token issuer**, **Sign
never issues tokens**, **JWT claims (not `CurrentAttributes`) are the runtime authorization
context**, and authorization is split into a **stateless GET path** and a **gated WRITE path**.
Logout becomes a **write-denial operation first**, cookie cleanup second, with **synchronous
propagation to regional services** over a private control-plane network.

This review measures that target against OAuth 2.1 / OIDC / RFC 9068 / the OAuth Security BCP and
session-management best practice, designs the concrete JWT, cookie, and database artifacts, and
attacks the logout and propagation design adversarially.

### What the code actually is today (grounding)

- **Issuance / signing:** ES384 JWTs via `lib/jit_security_jwt_keyring.rb` +
  `lib/jit_security_jwt_registry.rb`; access-token codec
  `app/services/security_jwt_auth_access_token_codec.rb`; claims builder
  `app/controllers/concerns/authorization_token_claims.rb`.
- **Current access-token claims** (`authorization_token_claims.rb:16-34`):
  `iat, exp, jti, sub, act, typ, iss, aud, scp, acr, amr, sid, auth_time, step_up_until, prf, cnf{jkt}`.
- **Runtime context:** `Actor` (`app/models/actor.rb`) is `ActiveSupport::CurrentAttributes`,
  hydrated per request from the decoded token + device-session row by
  `app/controllers/concerns/actor_support.rb`. 120+ `Actor.*` call sites across controller concerns.
- **Cookies:** auth cookies `auth_access / auth_refresh / auth_dbsc` gain the `__Host-` prefix in
  secure contexts (`authentication_cookie_name.rb`), `HttpOnly`, `SameSite=Strict`, host-only.
  Preference cookies use `__Secure-` and are **apex-scoped** for cross-subdomain SSO
  (`preference_io_keys.rb`, `adr/cookie-domain-scope-by-surface.md`). Rails session
  `__Host-session`, `SameSite=Lax`. Core BFF browser cookie `__Host-core_sid`, `SameSite=Lax`.
- **Logout:** primitive `Authentication::LogoutCurrentSession.call(token:)` revokes one
  device-session + its refresh-token family; composition `LogoutAllSessions.call(resource:)` loops
  the primitive (`adr/logout-primitive-and-composition.md`). Acme owns the mutation; Sign serves a
  static, state-free `/signed-out` page (`adr/logout-completion-boundary.md`). **No cross-service
  propagation exists** — the app is a single Rails monolith with logical surfaces, sharing one DB.

---

## §0 — Reconciliation: conflicts between the objective and accepted ADRs

These must be resolved explicitly before any implementation. I recommend the objective wins on each
(greenfield mandate), and the listed ADRs be superseded/amended.

| #   | Objective says                                                                                                     | Accepted ADR says                                                                                                                        | Severity     | Recommendation                                                                                                                                                                                                                                                       |
| --- | ------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------- | ------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| C1  | Regional surfaces are **Core / Palm / Side**                                                                       | Components are **Acme / Sign / Core / Base / Port**; no "Side"; "Palm" is only a transitional route name                                 | High         | Adopt one vocabulary. Map **Core→web BFF, Palm→native API (=Port), Side→new third regional surface**, or rename Side→Base. Do not ship three vocabularies. This review uses Core/Palm/Side per the objective and tags the repo equivalent.                           |
| C2  | **CurrentAttributes is being removed**; JWT claims are the runtime context                                         | `adr/actor-current-facade.md` (accepted) makes `Actor`-on-`CurrentAttributes` the _only_ context container                               | High         | Keep `Actor` as a **thin, request-scoped facade whose backing store is the verified JWT claim set**, not a mutable god-object. CurrentAttributes-the-mechanism can stay; CurrentAttributes-as-source-of-truth must go. Supersede the facade ADR's "source" language. |
| C3  | Cookie inventory implies the **browser carries access tokens**                                                     | `adr/acme-sign-core-base-port-boundary.md`: "Browsers must not directly hold bearer access tokens"; browser holds only `__Host-core_sid` | **Critical** | Keep the BFF rule. Browser holds **one opaque session cookie per origin**; all JWT access/refresh tokens live server-side (BFF / native keystore). This shrinks the browser attack surface to near-zero and is non-negotiable for the web path.                      |
| C4  | **Distributed regional services** across a private control-plane network, geographically distant, **no shared DB** | Reality is a **monolith, one DB, no service-to-service calls**                                                                           | High         | The propagation/mirror/outbox design below is correct _for the target topology_. Until the split happens, the same logic runs in-process against one DB (propagation = a local transaction). Build the interface now, the network later.                             |
| C5  | `prf` (preferences) is a **separate token, never authz**                                                           | Repo embeds `prf` inside the **access token** _and_ keeps a separate Preference JWT                                                      | Medium       | Endorse the objective: **delete `prf` from the access token.** Preferences are a non-authz token/cookie family only.                                                                                                                                                 |

---

## §1 — Standards Review

### 1.1 Alignment (keep)

- **OAuth 2.1:** native clients use Authorization Code + **PKCE**, no implicit/password grants —
  compliant.
- **Sender-constrained tokens:** DPoP (`cnf.jkt`) for native + DBSC for browsers is _ahead_ of
  baseline and directly satisfies the OAuth Security BCP "sender-constrained access tokens"
  recommendation.
- **Refresh-token rotation + reuse detection + family revocation**
  (`adr/refresh-revoke-aal-downgrade-and-replay-hardening.md`) — matches BCP §refresh-token best
  practice.
- **ID token vs access token separation** (`adr/acme-sign-core-base-port-boundary.md`,
  `adr/oidc-claims-decision.md`) — compliant; APIs must not authorize on ID tokens (already a
  guardrail).
- **`__Host-` auth cookies, `SameSite`, `HttpOnly`, idle+absolute+renewal timeouts**
  (`adr/session-token-hardening-baseline.md`) — matches OWASP session management.
- **Single issuer / Authorization Server (Acme)** — clean OIDC topology; Sign-as-RP is correct.

### 1.2 Deviations

| Deviation                                                                                    | Class                    | Notes                                                                                                                                                                                                                                                                                                                                                       |
| -------------------------------------------------------------------------------------------- | ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`scp` (array) instead of RFC 9068 `scope` (space-delimited string); no `client_id` claim** | Dangerous                | RFC 9068 §2.2 **requires** `client_id` and a `scope` string in JWT access tokens. Breaks interop with conformant resource servers and audit tooling. **Fix.**                                                                                                                                                                                               |
| **`typ` carried as a JWT _claim_** (`token_type`)                                            | Dangerous                | RFC 9068 puts `typ` in the **JOSE header** with value **`at+jwt`**; a body claim named `typ` is a different thing and provides no media-type protection against token-substitution. **Move to header.**                                                                                                                                                     |
| **Stateless GET (no revocation check)**                                                      | _Acceptable_             | Standard JWT tradeoff. Safe **only if** access-token TTL is short (≤5 min staff / ≤15 min end-user per `adr/token-lifetime-policy-by-surface.md`). The "logout doesn't immediately hide GET data" acceptance is fine **for non-sensitive reads**; sensitive reads (PII, security settings, billing) must be promoted to the WRITE/revocation-checked class. |
| **Single issuer key for global _and_ regional tokens**                                       | Dangerous if unmitigated | One signing key compromise = every region forgeable. Mitigate with **per-audience key separation** (distinct `kid` namespaces per regional audience) so blast radius is bounded; Acme still owns all of them.                                                                                                                                               |
| **Synchronous logout fan-out gating completion** (objective §Logout step 5)                  | **Dangerous**            | Couples logout _availability_ to _every_ regional service. One unreachable region ⇒ no user can complete logout (a built-in DoS and a support nightmare). See §4 for the fail-closed redesign that removes this coupling while keeping write-denial mandatory.                                                                                              |
| **Long browser session vs short access token**                                               | Acceptable               | Fine under the BFF model: the BFF holds the short access token and silently refreshes; the browser session cookie can be longer-lived but is itself revocable server-side.                                                                                                                                                                                  |

### 1.3 OIDC logout posture

The objective's bespoke "propagate logout to regional services" should be expressed in terms of
**OIDC Back-Channel Logout** semantics (a signed `logout_token` with `sid`/`sub`, `events` claim)
rather than an ad-hoc RPC. It is a standardized, replay-resistant primitive and you already
issue/verify signed short-lived tokens (`app/services/oidc_logout_request.rb`). Front-Channel Logout
(iframe-based) is **not** recommended — it is unreliable under modern cross-site cookie
partitioning.

---

## §2 — JWT Schema

**Principles:** standard claims first; one custom namespace `umx` for the few genuinely-custom
claims; RFC 9068 header (`typ: at+jwt`, `alg: ES384`, `kid`) on every _access_ token.

### 2.1 Preference Token — _not an access token, never authorizes_

| Claim          | Standard?    | Value / purpose                                                                                      |
| -------------- | ------------ | ---------------------------------------------------------------------------------------------------- |
| `iss`          | std          | Acme                                                                                                 |
| `iat`, `exp`   | std          | short-ish; refreshable                                                                               |
| `sub`          | std          | account id (so prefs follow the account)                                                             |
| `jti`          | std          | replay/rotation tracking                                                                             |
| `typ` (header) | RFC-style    | **`pref+jwt`** — explicitly _not_ `at+jwt`, so no resource server can mistake it for an access token |
| `locale`       | **OIDC std** | BCP47 (`ja-JP`) — replaces custom "language"                                                         |
| `zoneinfo`     | **OIDC std** | IANA tz (`Asia/Tokyo`) — replaces custom "timezone"                                                  |
| `umx.ui`       | custom       | object: `{theme, currency, date_fmt, time_fmt, motion, density, page_size, schema_ver}`              |

- **No `aud`** (or a sentinel `aud:"none"`): a preference token must be **structurally unusable** as
  an access token. Resource servers reject any token whose header `typ != at+jwt`.
- **Custom justification (`umx.ui`):** OIDC standardizes only `locale`/`zoneinfo`; there is no
  standard claim for theme/currency/density/etc. They are grouped under one namespaced object to
  keep the top-level namespace clean and signal "non-standard, non-security."

### 2.2 Global Access Token (Acme/Sign authentication context)

| Claim                     | Standard?        | Value / purpose                                  |
| ------------------------- | ---------------- | ------------------------------------------------ |
| header `typ`              | RFC 9068         | **`at+jwt`**                                     |
| `iss`                     | std              | Acme                                             |
| `sub`                     | std              | account id                                       |
| `aud`                     | std              | global resource servers (e.g. `["acme-api"]`)    |
| `client_id`               | **RFC 9068 req** | **ADD** (currently missing)                      |
| `iat`, `exp`, `jti`       | std/req          | `exp` short (≤5–15 min by surface)               |
| `scope`                   | **RFC 9068**     | space-delimited **string** (replace `scp` array) |
| `acr`, `amr`, `auth_time` | std (OIDC)       | assurance + freshness                            |
| `sid`                     | OIDC             | global session id — the revocation/logout key    |
| `cnf.jkt`                 | RFC 7800/9449    | DPoP / device binding                            |
| `umx.act`                 | custom           | actor class: `client` / `operator` / `visitor`   |

- **Drop:** `prf` (→ §2.1), `step_up_until` (express step-up via `acr` + a short-TTL step-up token,
  not a long-lived body claim that outlives its freshness window).
- **Custom justification (`umx.act`):** actor _class_/realm is an identity-type distinction, not a
  role or scope. OAuth/OIDC has no standard claim for it; `scope` already carries `domain:operator`
  but that is a _capability_ statement, not a stable identity-class. Keep `umx.act` for
  routing/policy, derive capabilities from `scope`.

### 2.3 Regional Access Tokens — Core / Palm / Side

Minted by Acme via **RFC 8693 Token Exchange** from (global auth context) × (regional DB state). One
template; the audience and region differ.

| Claim         | Standard? | Core                          | Palm            | Side            | Purpose                                                 |
| ------------- | --------- | ----------------------------- | --------------- | --------------- | ------------------------------------------------------- |
| header `typ`  | RFC 9068  | `at+jwt`                      | `at+jwt`        | `at+jwt`        | —                                                       |
| `iss`         | std       | Acme                          | Acme            | Acme            | single issuer, **per-audience `kid`**                   |
| `sub`         | std       | acct                          | acct            | acct            | account                                                 |
| `aud`         | std       | `core-api`                    | `palm-api`      | `side-api`      | the _only_ resource server that accepts it              |
| `client_id`   | RFC 9068  | ✓                             | ✓               | ✓               | exchanging client                                       |
| `iat/exp/jti` | std       | **very short exp (60–300 s)** | same            | same            | minimize revocation gap; re-mint on demand              |
| `scope`       | RFC 9068  | regional scopes               | regional scopes | regional scopes | capabilities                                            |
| `acr/amr`     | OIDC      | ✓                             | ✓               | ✓               | assurance carried down                                  |
| `sid`         | OIDC      | ✓                             | ✓               | ✓               | links to **global** session → WRITE-gate revocation key |
| `cnf.jkt`     | RFC 7800  | ✓                             | ✓               | ✓               | binding                                                 |
| `umx.region`  | custom    | `core`                        | `palm`          | `side`          | deployment region                                       |
| `umx.tenant`  | custom    | tenant/org id                 | …               | …               | multi-tenant write gate                                 |
| `umx.pv`      | custom    | int                           | int             | int             | **permission version** (see §5.3)                       |

- **Drop `access_mode` and `audience` as separate concepts:** `access_mode` is derivable from
  `scope` (presence of a `write:*` scope) — a redundant claim is an extra thing to keep consistent
  and an extra attack surface. `audience` is just `aud`. Destructive simplification: **delete
  both.**
- **Custom justifications:**
  - `umx.region` — no standard claim names a deployment region; needed so a regional RS can refuse
    tokens minted for a different region even if `aud` is misconfigured (defense in depth).
  - `umx.tenant` — `org`/`tenant` are not OAuth-standard; the WRITE gate needs tenant scoping
    cheaply.
  - `umx.pv` — there is no standard "permission epoch" claim. It lets the WRITE gate detect stale
    authority (role/membership change) in O(1) without a DB round-trip per read, and forces re-mint
    on change.
- **Short TTL is the strategy:** with 60–300 s regional tokens, most "revocation" needs are met by
  simply not re-minting; the heavy revocation machinery (§5) only has to cover the in-flight window.

### 2.4 Runtime helper interface (replaces `CurrentAttributes` as _source_)

The helper methods the objective lists are **pure functions over verified claims**, not stored
state:

```
actor_id    -> sub
sid         -> sid
region      -> umx.region
tenant_id   -> umx.tenant
audience    -> aud
scopes      -> scope (parsed)
access_mode -> derived: scope.any?(write:*) ? :write : :read   # not a claim
```

`Actor` may remain as a _request-scoped, immutable, read-through_ facade over the decoded token
(C2), but it must hold no authority the token does not already assert.

---

## §3 — Cookie Inventory

**Governing rule (C3):** the browser holds **no bearer tokens**. JWT access/refresh tokens are
server-side artifacts (BFF session store / native secure storage). Therefore the _browser_ cookie
inventory is deliberately tiny.

| Cookie                        | Prefix              | Path | SameSite | Secure | HttpOnly | Why it exists                                                                                                                                               | Purged on logout?                  |
| ----------------------------- | ------------------- | ---- | -------- | ------ | -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------- |
| `__Host-acme_sid`             | `__Host-`           | `/`  | `Lax`    | ✓      | ✓        | Opaque handle to the **global** server-side session at Acme. The one credential the browser carries. `Lax` to survive the OIDC top-level redirect/callback. | **Yes — primary**                  |
| `__Host-core_sid`             | `__Host-`           | `/`  | `Lax`    | ✓      | ✓        | Core BFF web session (already in the accepted ADR). Maps to server-side regional token cache.                                                               | Yes                                |
| `__Host-side_sid`             | `__Host-`           | `/`  | `Lax`    | ✓      | ✓        | Side regional BFF session (if Side is browser-facing).                                                                                                      | Yes                                |
| `__Secure-preference_access`  | `__Secure-`         | `/`  | `Lax`    | ✓      | ✓        | Apex-scoped Preference JWT (§2.1) for cross-subdomain UI consistency. Not authz.                                                                            | **No** (survives logout by design) |
| `__Secure-preference_refresh` | `__Secure-`         | `/`  | `Strict` | ✓      | ✓        | Rotates the preference token.                                                                                                                               | No                                 |
| `ct` (theme hint)             | `__Secure-` in prod | `/`  | `Lax`    | ✓      | **No**   | JS-readable theme hint to avoid first-paint flash (FOUC). Carries no identity.                                                                              | No                                 |
| `preference_consented`        | `__Secure-`         | `/`  | `Lax`    | ✓      | No       | Consent acknowledgment.                                                                                                                                     | No                                 |

**Notes & opinions:**

- **Palm has no cookies.** Native clients use `Authorization: Bearer` + DPoP; cookies are a browser
  concept.
- **No `__Host-auth_access` / `__Host-auth_refresh` browser cookies in the target.** These exist
  today (`authentication_cookie_name.rb`) under the Rails-native model and **conflict with C3**.
  Retire them on the web path; Base (Rails-rendered) may keep an HttpOnly server-session cookie (not
  a raw JWT) during transition.
- **`__Host-` for every session cookie**, **never** `Domain=` for session/auth cookies (kills
  subdomain cookie-injection and forced-host attacks). Only the _preference_ family is apex-scoped,
  and it is non-authz (XSS theft of a preference cookie is low-impact) — consistent with
  `adr/cookie-domain-scope-by-surface.md`.
- **`SameSite`:** session cookies are `Lax` (must survive the OIDC redirect entry);
  rotation/refresh-class cookies are `Strict`. No auth cookie is ever `SameSite=None`.
- **Deleted during logout:** every `*_sid` session cookie (global + regional). Preference and
  UI-hint cookies **survive** — they carry no authority and surviving them avoids re-prompting
  locale/theme. This matches the objective's "cookie purge is secondary / best-effort."

---

## §4 — Logout Design (adversarial)

### 4.1 The flaw in the proposed sequence

The objective requires: mark `sid` write-denied → **synchronously propagate to all regions** → wait
for **all ACKs** → only then purge cookies → show completion; **if propagation fails, logout does
not complete.** This is wrong for three reasons:

1. **Availability coupling / self-DoS.** Any one unreachable or slow region blocks _every_ user's
   logout. An attacker who can degrade one region's control-plane endpoint can prevent logouts
   platform-wide.
2. **It solves the wrong problem.** Logout's security goal is "**no further writes** on this
   session." That is guaranteed by the WRITE gate's revocation check — _not_ by an ACK. If the WRITE
   gate fails closed (§4.3), a region that never received the logout still denies writes.
3. **Cookie purge ordering is user-hostile.** A user who closed the laptop mid-logout keeps a live
   session cookie pointing at a server session that _is_ revoked — confusing but not unsafe — yet
   the proposed design would also block the completion page.

### 4.2 Recommended logout model (opinionated)

> **Logout completes locally and immediately. Write-denial is guaranteed by fail-closed WRITE gates
> plus guaranteed-eventual propagation, not by synchronous ACKs.**

1. User requests logout at Acme.
2. **In one atomic transaction at Acme:** set global session `status = revoked`, bump the session's
   `perm_version`, append rows to the **logout-propagation outbox** (one per region), and revoke the
   refresh-token family. _Logout is now authoritative._
3. **Purge the global session cookie immediately** and render/redirect to the static `/signed-out`
   page (`adr/logout-completion-boundary.md` — Sign page stays state-free).
4. A **durable outbox worker** pushes revocations to each regional mirror with **idempotent,
   monotonic `(sid, seq)`** messages, retrying with backoff until acked. Regions also **pull** the
   revocation list (anti-entropy) on a short interval so a missed push self-heals.
5. Cookie purge of regional `*_sid` cookies is **best-effort** (the browser may not visit those
   origins); it is _not_ required for safety because regional WRITE gates fail closed.

**Result:** mandatory write-denial is preserved; availability coupling is eliminated; the
objective's intentional acceptances (GET may lag, cookie purge best-effort) are honored.

### 4.3 The load-bearing invariant: WRITE gates fail **closed**

A regional WRITE must require a **positive, fresh** liveness confirmation of `sid`:

```
ALLOW write iff: token valid ∧ sid present in regional mirror as status=live
                 ∧ mirror entry freshness ≤ max_staleness ∧ token.umx.pv == current_pv
ELSE deny (re-auth / re-mint).
```

So a region that **cannot confirm** a session is live (never received it, stale mirror, partition)
**denies writes**. Logout safety no longer depends on the logout message _arriving_; it depends on
the region being _unable to assert liveness_, which is the safe default.

### 4.4 Attack & failure scenarios

| Scenario                             | Vector                                                                | Mitigation                                                                                                              |
| ------------------------------------ | --------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| **Logout-not-honored**               | Region never gets the revocation                                      | Fail-closed gate (§4.3) + anti-entropy pull; region denies writes when mirror is stale.                                 |
| **Replay of logout message**         | Attacker re-sends an old logout RPC                                   | Monotonic `(sid, seq)`; idempotent apply; signed `logout_token` (OIDC back-channel) with `jti` consumed once.           |
| **Replay to _un_-logout**            | Attacker replays an older "session live" push to revive a revoked sid | Mirror only accepts `seq` strictly greater than stored; revoked is terminal (status can't regress).                     |
| **Logout loop / storm**              | Mass logout fans out and overwhelms regions                           | Outbox is rate-limited + batched; pull-based anti-entropy bounds push volume; per-region backpressure.                  |
| **Purge-chain failure**              | Browser abandons mid-purge                                            | Irrelevant to safety (server session already revoked); regional cookies are inert without a live mirror entry.          |
| **Partial regional failure**         | 1 of N regions down                                                   | Logout still completes; down region fails closed (denies writes); outbox drains on recovery.                            |
| **Pre-logout token still in flight** | Short-TTL regional token minted just before logout                    | Bounded by 60–300 s TTL **and** `umx.pv` mismatch after the perm bump; WRITE gate rejects on `pv`.                      |
| **GET data exposure after logout**   | Stateless GET keeps serving until token expiry                        | Accepted by design for non-sensitive reads; sensitive GETs promoted to revocation-checked class; TTL bounds the window. |
| **Browser back-button / bfcache**    | Cached authenticated page shown post-logout                           | `Cache-Control: no-store` on authenticated responses (already in hardening baseline); back-nav re-hits the gate.        |
| **Cross-tab desync**                 | Tab A logs out, tab B still "in"                                      | Tab B's next write fails closed; optionally a logout broadcast via `BroadcastChannel`/storage event (UX only).          |
| **CSRF-forced logout**               | Attacker forces victim logout                                         | Logout is a state-changing POST with CSRF token + `SameSite`; annoyance only, not a compromise.                         |

---

## §5 — Database Model

Schemas are topology-agnostic: in the monolith they are tables in one DB; in the split they live at
Acme (authoritative) and per-region (mirror). **No shared DB across regions** (C4).

### 5.1 Global Session Registry (authoritative, Acme)

```
sessions
  id                bigint pk
  public_id         text unique        -- the `sid` claim (NanoID-21)
  account_id        bigint not null
  actor_class       enum(client,operator,visitor)
  status            enum(active,logout_reserved,revoked) not null default active
  aal               text               -- aal1/aal2
  amr               text[]             -- methods used
  cnf_jkt           text               -- device binding thumbprint
  perm_version      bigint not null default 0
  ip_hmac           text               -- coarse /24|/48 HMAC (risk signal only)
  created_at        timestamptz
  last_seen_at      timestamptz
  idle_expires_at   timestamptz
  absolute_expires_at timestamptz
  revoked_at        timestamptz
  revoked_reason    text
  index(account_id, status), index(public_id)

refresh_token_families
  id                bigint pk
  session_id        bigint fk -> sessions
  current_generation int not null
  rotated_at        timestamptz
  reuse_detected_at  timestamptz
  revoked_at        timestamptz
```

### 5.2 Regional Session Mirror (per region; eventually consistent)

```
session_mirror
  sid               text pk            -- mirrors sessions.public_id
  status            enum(live,write_denied,revoked) not null
  perm_version      bigint not null
  not_after         timestamptz        -- hard ceiling; treat as revoked past this
  last_seq          bigint not null    -- monotonic; reject <= last_seq
  updated_at        timestamptz not null   -- freshness for the fail-closed check
  index(updated_at)
```

Fail-closed rule: **absence, `updated_at` older than `max_staleness`, or `now > not_after` ⇒ deny
writes.**

### 5.3 Permission Versioning

```
account_permission_epoch
  account_id        bigint pk
  perm_version      bigint not null default 0   -- bumped on any role/membership/scope change
  updated_at        timestamptz

memberships
  ... existing columns ...
  perm_version      bigint not null             -- snapshot at last change
```

Regional tokens carry `umx.pv = account_permission_epoch.perm_version` at mint time. The WRITE gate
compares `token.umx.pv` to the mirror's `perm_version`; mismatch ⇒ deny + force re-mint. This
invalidates authority **without** waiting for token expiry and without a per-read DB hit.

### 5.4 Logout Propagation Tracking (durable outbox)

```
logout_propagations
  id                bigint pk
  sid               text not null
  region            enum(core,palm,side) not null
  seq               bigint not null            -- monotonic per sid
  state             enum(pending,acked,failed) not null default pending
  attempts          int not null default 0
  last_error        text
  created_at        timestamptz
  acked_at          timestamptz
  unique(sid, region, seq)
```

The transaction in §4.2-step-2 writes these rows; the worker drains them; regions ack idempotently.
This is the standard **transactional outbox** pattern — it guarantees at-least-once delivery without
distributed transactions, and idempotency makes at-least-once safe.

---

## §6 — Architecture Attack Review (ranked)

### Critical

- **C-1 — Browser-held bearer tokens (if C3 is not enforced).** Today's `__Host-auth_access` cookie
  places a signed access token in the browser. Combined with any XSS or a `SameSite` gap, this is
  direct token theft. _Fix:_ enforce the BFF model — browser holds only opaque `*_sid`.
- **C-2 — Synchronous logout fan-out as a completion gate.** Built-in platform-wide self-DoS (§4.1).
  _Fix:_ §4.2 outbox + fail-closed gates.
- **C-3 — Single signing key across global + regional audiences.** One key compromise forges every
  region. _Fix:_ per-audience `kid` separation; short regional TTL; documented rotation.

### High

- **H-1 — WRITE gate that fails _open_ on mirror unavailability.** Would make logout unenforceable
  during any partition. _Fix:_ the fail-closed invariant (§4.3) is mandatory, not optional.
- **H-2 — RFC 9068 nonconformance (`scp` array, missing `client_id`, body `typ`).**
  Token-substitution / audience-confusion risk and broken RS interop. _Fix:_ §2.2.
- **H-3 — Permission change not reflected until token expiry.** Without `umx.pv` (§5.3), a demoted
  operator keeps write authority for the token lifetime. _Fix:_ perm-version gate.
- **H-4 — Token exchange (Acme minting regional tokens) under-specified.** Must validate the global
  token's `sid` is still `live`, bind the regional token to that `sid`, and refuse exchange for
  revoked/expired sessions. _Fix:_ exchange is a WRITE-class operation that runs the §4.3 check.

### Medium

- **M-1 — Step-up freshness via long-lived `step_up_until` claim.** A claim outliving its freshness
  window is forgeable freshness. _Fix:_ short-TTL step-up token + `acr` elevation, re-checked at the
  gate.
- **M-2 — Sensitive GETs treated as stateless.** "Logout doesn't hide GET data" is fine for a public
  profile, not for billing/security pages. _Fix:_ a sensitive-read class that runs the revocation
  check.
- **M-3 — Preference token confusable with access token.** If a RS ever accepted a token by
  signature alone, a preference token could authorize. _Fix:_ RS rejects any token whose header
  `typ != at+jwt`; preference token has no `aud`.
- **M-4 — Anti-entropy pull interval = the worst-case write-denial latency.** Document and bound
  `max_staleness`; alert when a region's mirror lags.

### Low / Informational

- **L-1 — Cross-tab logout desync** (UX, §4.4).
- **L-2 — bfcache/back-button** — covered by `no-store`, verify it's applied to _all_ authenticated
  responses.
- **L-3 — Surface-vocabulary drift (Core/Palm/Side vs Core/Base/Port)** — operational confusion,
  audit ambiguity. Resolve C1.
- **L-4 — Preference cookie apex scope** — accepted XSS-read risk; acceptable because non-authz.

---

## §7 — Final Recommended Architecture (opinionated)

1. **Acme is the only issuer; Sign issues nothing.** (Already accepted — keep.) Regional tokens are
   minted by Acme via **RFC 8693 token exchange**, short-lived (60–300 s), per-audience keys.
2. **The browser holds exactly one opaque session cookie per origin** (`__Host-*_sid`,
   `SameSite=Lax`, `Secure`, `HttpOnly`). **No JWT ever reaches browser JS or browser cookies.**
   Native clients use `Bearer` + DPoP. _(Resolves C3 / C-1.)_
3. **`Actor` survives as an immutable, request-scoped, read-through facade over verified JWT
   claims** — never a mutable source of truth. Helper methods (`actor_id`, `sid`, `region`,
   `tenant_id`, `scopes`) are pure functions over claims; `access_mode` is derived, not stored.
   _(Resolves C2.)_
4. **Two-track authorization.** GET = stateless JWT validation (short TTL bounds exposure; sensitive
   GETs are promoted). WRITE = JWT validation + **fail-closed** `sid` liveness + `perm_version` +
   membership + permission + transaction. _(The §4.3 invariant is the keystone.)_
5. **Logout completes locally and immediately**; write-denial is guaranteed by fail-closed gates +
   transactional-outbox propagation + anti-entropy pull, expressed as **OIDC back-channel
   `logout_token`**. Cookie purge is best-effort. _(Resolves C-2.)_
6. **RFC 9068-conformant access tokens:** header `typ=at+jwt`, `scope` string, `client_id`, drop
   body `typ`, drop `prf`, drop `step_up_until`. Preference data lives only in the `pref+jwt` token.
   _(Resolves H-2, C5.)_
7. **Four DB artifacts:** global session registry, regional session mirror, permission epoch, logout
   outbox (§5) — one DB today, Acme-authoritative + per-region mirrors after the split.
8. **Reject the synchronous-ACK gate, `access_mode`/`audience` claims, body `typ`, browser bearer
   tokens, and the third surface-vocabulary.** Destructive simplification, as requested.

### Risk analysis summary

| Severity | Finding                                                                                                |
| -------- | ------------------------------------------------------------------------------------------------------ |
| Critical | C-1 browser bearer tokens · C-2 sync-fan-out gate · C-3 single signing key                             |
| High     | H-1 fail-open WRITE gate · H-2 RFC 9068 gaps · H-3 perm-change latency · H-4 token-exchange under-spec |
| Medium   | M-1 long step-up claim · M-2 sensitive GETs · M-3 token confusion · M-4 staleness latency              |
| Low      | L-1 cross-tab · L-2 bfcache · L-3 vocab drift · L-4 pref apex scope                                    |

---

## Verification (how to validate this design — no code is changed here)

Because this is a design review, "verification" means validating the _design_, not running an app:

1. **Standards conformance check:** lint a sample of each proposed token against RFC 9068 (header
   `typ`, `client_id`, `scope` string) and OIDC ID-token requirements; confirm preference tokens are
   rejected by a mock resource server (`typ != at+jwt`, no `aud`).
2. **Logout safety walk-through (tabletop):** for each §4.4 row, trace the request through the §4.3
   invariant and confirm "deny" is the outcome under partition, replay, and stale-mirror conditions.
3. **Invariant test list to hand to implementation** (Minitest, when built): fail-closed WRITE under
   stale mirror; `perm_version` mismatch denies write; revoked `sid` blocks token exchange; outbox
   idempotency on duplicate `(sid, seq)`; monotonic `seq` rejects regression; preference token
   cannot authorize.
4. **ADR reconciliation:** before implementation, supersede/amend `adr/actor-current-facade.md`
   (C2), `adr/acme-sign-core-base-port-boundary.md` naming (C1), and
   `adr/logout-completion-boundary.md` / `adr/logout-primitive-and-composition.md` (add
   propagation + write-denial), and resolve the `auth_access` browser-cookie conflict (C3).

> **Note on artifact location:** repo convention (and prior user direction) is to keep
> design/evaluation reports under `memos/` as dated flat files and decisions under `adr/`. In plan
> mode I can only write this plan file; on approval this review should be moved to
> `memos/2026-06-14-auth-token-session-logout-architecture-review.md`, and the C1–C5 conflicts
> promoted to ADR amendments.
