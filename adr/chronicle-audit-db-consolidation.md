# Chronicle Audit DB Consolidation (2026-04-23)

## Status

Accepted

## Supersedes

- `activity-journal-chronicle-db-model-naming.md`

## Context

The repository previously split audit-style persistence across multiple database families:

- `activity` for global audit records
- `behavior` for regional behavior records
- `setting` for `settings_preference_activities`
- `occurrence` for counters and rate-limit style occurrence records

That split was tied to an earlier architecture that depended on engine-era global and regional
boundaries.

We have now decided to move forward with independent Rails applications instead of completing the
failed Rails engine shift. Under that direction, the old `global` and `regional` separation is no
longer the right naming and interface boundary for audit-style records.

At the same time, the current naming is inconsistent:

- audit-like records use both `Activity` and `Behavior`
- the shared base classes are split across `ActivityRecord` and `BehaviorRecord`
- `SettingPreferenceActivity` is named like an activity record but actually uses `SettingRecord`

The result is an avoidable interface split across the four Rails applications:

- `identity`
- `foundation`
- `zenith`
- `distributor`

We want one audit-domain name and one base interface for all audit-style persistence.

`occurrence` remains a different concern. It tracks counters, anomaly detection, and rate-limit
style frequency records rather than audit history. It is not part of this consolidation.

## Decision

We will consolidate all audit-style persistence under the single domain name `chronicle`.

### Database

- Introduce one physical `chronicle` database with `chronicle` and `chronicle_replica` connections.
- Move the current `activity` and `behavior` data families into `chronicle`.
- Move `settings_preference_activities` out of the `setting` database and into the chronicle domain.
- Keep `occurrence` as a separate database and naming family.

### Base model and interface

- Replace `ActivityRecord` and `BehaviorRecord` with `ChronicleRecord`.
- Use `ChronicleRecord` as the common base interface for all audit-style records.
- Do not keep compatibility aliases for the old record names.

### Model and table naming

- Rename audit-style model families from `*Activity` and `*Behavior` to `*Chronicle`.
- Rename the corresponding event and level catalogs to `*ChronicleEvent` and `*ChronicleLevel`.
- Rename the corresponding tables to chronicle naming as part of the same migration window.
- Keep family-specific tables. We are standardizing the domain name and interface, not collapsing
  everything into a single generic entry table.

### Audit contract

- Promote the stronger audit contract to all chronicle families.
- Former behavior families must adopt the same audit-oriented contract used by the stronger activity
  families, including sequence and digest support.
- Tamper-evident fields and validation behavior become part of the chronicle domain contract rather
  than remaining limited to selected families.

### Scope boundaries

- `occurrence` stays unchanged in database, model family, and naming.
- This ADR defines the accepted architecture decision. Detailed migration sequencing and file-level
  execution plans belong in implementation plans, not in this ADR.

## Consequences

- The four Rails applications can depend on one audit-domain name and one shared base interface.
- The old `activity` versus `behavior` distinction stops being part of the public persistence
  vocabulary.
- `SettingPreferenceActivity` stops being a naming exception and becomes part of the chronicle
  domain.
- The migration is intentionally disruptive: class names, table names, fixtures, tests, and
  connection names will change together.
- No compatibility layer means downstream code must be updated in one coordinated migration window.
- `occurrence` remains available for rate limiting and anomaly tracking without being forced into an
  audit abstraction it does not fit.
