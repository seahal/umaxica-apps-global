# ADR: Preference Soft Bubble Doctrine

**Status:** Accepted (2026-05-06)

> **Partial supersession (2026-05-13):** `adr/actor-current-facade.md` supersedes this ADR's
> application-facing read API. `Actor::Preference` is the value-object shape, and application code
> reads it through `Actor.preference`.
>
> **Placement update (2026-05-18):** Session-side surface preference families now live in
> `app_setting`, `org_setting`, and `com_setting`. Actor-local preferences stay in the matching
> principal database.
>
> **Runtime overlay update (2026-05-19):** `Actor.preference` is the effective request runtime
> preference. Normal authenticated requests build it from the verified access-token `prf` claim,
> then overlay valid request-local `lx`, `ct`, and `tz` parameters when explicitly present. The
> overlay is not a write path and must never be copied back to the database or JWT.
>
> **Preference edit entry update (2026-05-19):** Logged-in HTML preference edit screens are a
> bounded DB -> JWT refresh point. They may copy the actor-local preference DB value into the
> current surface preference and reissue the preference access-token before `Actor.preference` is
> initialized, so edits made in another environment are visible on the edit screen.
>
> **Surface write-boundary update (2026-05-19):** Preference setting writes belong to the `sign`
> surfaces. `apex` and `jump` consume the resolved runtime preference through `Actor.preference` and
> must treat preference state as read-only. Request context overlays, RP rendering, and jump
> redirects are not preference write paths.

## Context

The preference subsystem (region / language / timezone / theme / cookie consent) has been through
several reorganization attempts that did not converge. The result is that the codebase state and the
planning documents disagree:

- `adr/setting-preference-remove-polymorphic-owner.md` describes a `settings_preferences`
  polymorphic-owner table that does not exist.
- `plans/backlog/gh628-move-preferences-to-setting-db.md` planned to move all session-side
  preferences to one database; this was abandoned. Each surface now has its own setting database.
- `Preference::StorageAdapter`, the dual-read / dual-write layer that GH-628 introduced, has been
  removed.
- `adr/current-context-boundary-by-engine.md` explicitly notes that a single-app `Current` design
  "should be addressed in a separate ADR if needed" — that ADR was never written.

The current factual state (2026-05-06) is:

| DB              | Preference tables hosted | Note                            |
| --------------- | ------------------------ | ------------------------------- |
| `app_setting`   | `app_preference_*`       | App TLD session-side preference |
| `app_principal` | `user_preference_*`      | App actor-side local preference |
| `org_setting`   | `org_preference_*`       | Org TLD session-side preference |
| `org_principal` | `staff_preference_*`     | Org actor-side local preference |
| `com_setting`   | `com_preference_*`       | Com TLD session-side preference |
| `com_principal` | `visitor_preference_*`   | Com actor-side local preference |

Relevant runtime code is already in place:

- `app/models/actor.rb` defines `Actor < ActiveSupport::CurrentAttributes` with a `preference` slot.
- `app/models/actor/preference.rb` defines `Actor::Preference`, an immutable value object with a
  `from_jwt` constructor and a `NULL` instance for guests / bearer-only requests.
- `app/controllers/concerns/actor_support.rb` resolves `Actor.preference` via a three-stage
  fallback: actor-side DB record → JWT `prf` claim → `NULL`.

Past plans assumed two things that we now reject:

1. That all preference data should be consolidated into a single database.
2. That session-side models (`AppPreference` / `ComPreference` / `OrgPreference`) should be replaced
   by JWT snapshots alone.

We need a stable doctrine that the next round of cleanup work can reference, instead of continuing
to follow plans whose premises no longer hold.

## Decision

We adopt the **Preference Soft Bubble Doctrine**:

### 1. Databases stay separate (the soft bubbles)

The preference subsystem maps to TLDs as follows. Each TLD's preference state stays inside its own
bubble so that token / preference data does not bleed across TLDs:

- **app TLD** → `app_setting` for `AppPreference`, `app_principal` for `UserPreference` and auth.
- **org TLD** → `org_setting` for `OrgPreference`, `org_principal` for `OperatorPreference` and
  auth.
- **com TLD** → `com_setting` for `ComPreference`, `com_principal` for `VisitorPreference` and auth.

Each database is a **soft bubble**: changes inside one bubble must not require coordinated changes
in other bubbles. This is a deliberate constraint to limit blast radius. We do not pursue
cross-database consolidation.

The current placement keeps session-side and actor-side preference state separate:

- `AppPreference` lives in `app_setting`; `UserPreference` lives in `app_principal`.
- `OrgPreference` lives in `org_setting`; `OperatorPreference` lives in `org_principal`.
- `ComPreference` lives in `com_setting`; `VisitorPreference` lives in `com_principal`.

Login-time sync between session-side and actor-side preferences is therefore an explicit
cross-database synchronization boundary.

### 2. Interface is unified through `Actor::Preference`

`Actor::Preference` is the only runtime read interface for preference values. Application code
(controllers, views, services) reads preference state via `Actor.preference.<field>` and never
reaches into per-DB preference models for runtime reads. This includes `apex` and `jump`, which are
preference consumers, not preference setting writers. The differences between DB shapes are absorbed
at the `ActorSupport` boundary, not pushed up into callers.

For normal authenticated requests, `Actor.preference` is the effective request runtime preference:

```text
DB -> access-token JWT prf -> Actor.preference
request lx/ct/tz -> Actor.preference request overlay
```

Valid request-local `lx`, `ct`, and `tz` parameters may change the current request's effective
language, theme, or timezone. They do not update the database, reissue JWTs, or mutate persistent
preference state. If a token says `lx=ja` and a request says `lx=en`, the request renders in English
while the persistent preference remains Japanese.

Logged-in HTML preference edit screens are a bounded exception to the normal runtime cache path.
Before initializing `Actor.preference`, they may read the actor-local preference database, copy it
to the current surface preference, and issue a fresh access-token JWT. This exception exists only
for preference screen entry; it is not a generic database fallback for normal pages or broken JWTs.

Explicit preference setting writes still go to the per-DB models (since the bubbles are real), but
those writes are owned by the `sign` preference surfaces. `apex` and `jump` must not persist
preference changes; they may only consume `Actor.preference` and apply request-local overlays that
do not write the database or reissue JWTs. Read-side coupling to the per-DB models is to be removed
over time.

### 3. Session-side preference families are not retired

`AppPreference` / `ComPreference` / `OrgPreference` and their child / option / cookie / chronicle
tables stay. They were introduced to manage preference state on the front-end side without forcing
the client to own it; replacing them with JWT-snapshot-only would regress the design intent. The JWT
`prf` claim is a transport mechanism, not a replacement for the DB-backed session-side store.

### 4. `guest` is the com TLD authentication DB, not a "guest / anonymous" DB

The name `guest` is historical. It hosts the com TLD's actor identity and authentication data
(`customers`, `customer_passkeys`, `customer_emails`, `customer_telephones`, `customer_secrets`,
plus contact tables). It is not a preference database. After `customer_preferences` exits per the
move plan above, `guest` contains no preference tables and serves only as com TLD auth + contact
storage.

## Consequences

### Positive

- Stops the cycle of contradictory consolidation plans.
- Code paths that depend on `Actor::Preference` are stable — DB rearrangement does not change the
  read interface.
- Each preference DB can evolve at its own pace within its bubble.
- `guest` becomes single-purpose (com TLD authentication + contact data; no preference data).

### Negative

- Schema and model duplication across App / Com / Org families remains and must be addressed through
  other means (interface abstraction, not database merging).
- The Customer side schema (currently denormalized) is structurally different from User / Staff;
  this asymmetry must be addressed as a separate decision.
- `Preference::Adoption` (login-time sync between session-side and actor-side) needs its role
  re-evaluated under this doctrine but is not removed by this ADR.

### Follow-up work

The following are explicitly out of scope of this ADR and will be addressed in separate plans:

- **B2** — actor-side schema asymmetry (User / Staff normalized vs Customer denormalized)
- **B3** — `Preference::Adoption` role re-evaluation and possible reduction
- **C3** — `Preference::ClassRegistry` duplication reduction (App / Com / Org entries abstracted
  instead of dropped)
- **A5** — per-subdomain `Current` (jump / apex / sign) design, if needed

## Related

- `adr/current-context-boundary-by-engine.md` — superseded predecessor (engine-split era)
- `adr/setting-preference-remove-polymorphic-owner.md` — withdrawn (premise table never built)
- `plans/archive/gh628-move-preferences-to-setting-db.md` — rejected predecessor plan
- `plans/backlog/legacy-preference-models-retirement-plan.md` — to be rewritten under this doctrine
- `plans/archive/customer-preferences-move-to-com-preference-db.md` — superseded com TLD bubble
  closure note
- `plans/archive/staff-preference-move-to-operator-db.md` — historical org TLD bubble closure note
- `plans/backlog/gh578-preference-consolidation.md` — `Actor::Preference` runtime consolidation
  (still relevant)
- `plans/archive/actor-support-integration-test-coverage.md` — `ActorSupport` request-lifecycle test
  coverage gap
