# ADR: Preference Soft Bubble Doctrine

**Status:** Accepted (2026-05-06)

## Context

The preference subsystem (region / language / timezone / theme / cookie consent) has been through
several reorganization attempts that did not converge. The result is that the codebase state and the
planning documents disagree:

- `adr/setting-preference-remove-polymorphic-owner.md` describes a `settings_preferences`
  polymorphic-owner table that does not exist.
- `plans/backlog/gh628-move-preferences-to-setting-db.md` plans to move all session-side preferences
  to one `setting` database; this was abandoned (only `com_preference_*` moved).
- `Preference::StorageAdapter`, the dual-read / dual-write layer that GH-628 introduced, has been
  removed.
- `adr/current-context-boundary-by-engine.md` explicitly notes that a single-app `Current` design
  "should be addressed in a separate ADR if needed" — that ADR was never written.

The current factual state (2026-05-06) is:

| DB          | Preference tables hosted                                                                 | Note                                                                                                   |
| ----------- | ---------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `principal` | `app_preference_*`, `user_preference_*`, `staff_preference_*` ⚠️, `user_app_preferences` | App TLD session-side + User actor-side; **`staff_preference_*` is out-of-place here**                  |
| `operator`  | `org_preference_*`, `staff_org_preferences`                                              | Org TLD session-side; `staffs` (identity) and `staff_passkeys` / `staff_emails` / etc. also in this DB |
| `setting`   | `com_preference_*`, `customer_preference_*` (move in progress)                           | Com TLD preference (both session-side and actor-side)                                                  |
| `guest`     | `customer_preferences` (move in progress, leaving)                                       | Com TLD authentication DB (`customers` + `customer_passkeys` / `_emails` / etc.) — by design           |

Relevant runtime code is already in place:

- `app/models/current.rb` defines `Current < ActiveSupport::CurrentAttributes` with a `preference`
  slot.
- `app/models/current/preference.rb` defines `Current::Preference`, an immutable value object with a
  `from_jwt` constructor and a `NULL` instance for guests / bearer-only requests.
- `app/controllers/concerns/current_support.rb` resolves `Current.preference` via a three-stage
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

- **app TLD** → `principal` bubble (`AppPreference` + `UserPreference` + `User` + User auth)
- **com TLD** → `setting` bubble for preference + `guest` bubble for authentication. The split is
  intentional: `guest` is com TLD's authentication DB (`customers` + `customer_passkeys` / `_emails`
  / `_telephones` / `_secrets`) and the name is historical.
- **org TLD** → `operator` bubble (`OrgPreference` + `StaffPreference`(target) + `Staff` + Staff
  auth)

Each database is a **soft bubble**: changes inside one bubble must not require coordinated changes
in other bubbles. This is a deliberate constraint to limit blast radius. We do not pursue
cross-database consolidation.

Two known structural anomalies are being corrected as one-time exits, and these are the only
structural DB changes permitted under this doctrine:

- **com TLD**: `customer_preferences` moves `guest` → `setting` so that com preference state is
  co-located. See `plans/backlog/customer-preferences-move-to-setting-db.md`.
- **org TLD**: `staff_preferences` moves `principal` → `operator` so that org preference state is
  co-located with `staffs` and Staff credentials. See
  `plans/backlog/staff-preference-move-to-operator-db.md`.

After both moves complete, login-time double-write between session-side and actor-side
(`Preference::Adoption`, `Preference::Core#sync_to_resource_preference!`) becomes a same-DB
operation in all three TLDs, and `Preference::Adoption#resolve_cross_db_option_id` (currently
required to bridge the cross-DB sync for org and com TLDs) becomes dead code.

### 2. Interface is unified through `Current::Preference`

`Current::Preference` is the only runtime read interface for preference values. Application code
(controllers, views, services) reads preference state via `Current.preference.<field>` and never
reaches into per-DB preference models for runtime reads. The differences between DB shapes are
absorbed at the `CurrentSupport` boundary, not pushed up into callers.

Writes still go to the per-DB models (since the bubbles are real), but read-side coupling to those
models is to be removed over time.

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
- Code paths that depend on `Current::Preference` are stable — DB rearrangement does not change the
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
- `plans/backlog/customer-preferences-move-to-setting-db.md` — com TLD bubble closure (one of two
  allowed DB moves)
- `plans/backlog/staff-preference-move-to-operator-db.md` — org TLD bubble closure (the other
  allowed DB move)
- `plans/backlog/gh578-preference-consolidation.md` — `Current::Preference` runtime consolidation
  (still relevant)
- `plans/backlog/current-support-integration-test-coverage.md` — `CurrentSupport` request-lifecycle
  test coverage gap
