# Legacy Preference Models Retirement Plan

## Issue

GitHub #691

## Doctrine Reference

This plan operates under `adr/preference-soft-bubble-doctrine.md` (2026-05-06):

- Preference databases stay **separate** (`principal` / `operator` / `setting`).
- `guest` is **not** a preference database long-term — `customer_preferences` exits per
  `plans/backlog/customer-preferences-move-to-setting-db.md`.
- `Actor::Preference` is the **single runtime read interface**.
- Session-side families (`AppPreference` / `ComPreference` / `OrgPreference`) are **not retired**;
  they were introduced deliberately so the front-end side does not own preference state.

This rewrites the earlier 2026-04 version of this plan, which assumed full database consolidation
and retirement of all session-side models. Those assumptions are no longer correct.

## Goal

Reduce preference-model duplication and dead code without changing database boundaries.

What "retirement" means under the soft-bubble doctrine:

- **Retire**: schema duplication that has no behavioral need (e.g., 3 near-identical option tables;
  obsolete bridge / status / activity tables that no caller reads).
- **Retire**: Ruby class duplication where one shared abstraction is sufficient (e.g., collapsing
  per-prefix code that differs only by class name).
- **Retire**: legacy bridge tables (`user_app_preferences`, `staff_org_preferences`) if and when
  they have no behavioral purpose.
- **Keep**: `AppPreference` / `ComPreference` / `OrgPreference` themselves.
- **Keep**: User / Staff / Customer actor-side records.

## Current State (2026-05-06)

### Preference DBs and what lives there

| DB          | Session-side       | Actor-side                                          | Bridge                  | TLD |
| ----------- | ------------------ | --------------------------------------------------- | ----------------------- | --- |
| `principal` | `app_preference_*` | `user_preference_*`, `staff_preference_*` ⚠️        | `user_app_preferences`  | app |
| `operator`  | `org_preference_*` | (target for `staff_preference_*` after move)        | `staff_org_preferences` | org |
| `setting`   | `com_preference_*` | `customer_preference_*` (move from `guest` ongoing) | —                       | com |
| `guest`     | —                  | `customer_preferences` (leaving)                    | —                       | com |

Two planned moves are in flight (driven by separate plans, not by this retirement plan):

- `customer_preferences`: `guest` → `setting`
  (`plans/backlog/customer-preferences-move-to-setting-db.md`)
- `staff_preference_*`: `principal` → `operator`
  (`plans/backlog/staff-preference-move-to-operator-db.md`)

After both moves complete, every TLD's preference data (session-side and actor-side) is co-located
within its bubble. `guest` retains its role as the com TLD authentication DB (`customers`,
`customer_passkeys`, etc.) and holds no preference tables.

### Class registry (per-prefix duplication)

`app/services/preference/class_registry.rb` declares **6 prefixes** (`App`, `Com`, `Org`, `User`,
`Staff`, `Customer`), each with up to 8 sub-keys:

- `preference`, `status`, `cookie`, `audit`, `audit_event`, `audit_level`, `option_classes` (4),
  `record_classes` (4)

Concrete model count today (under `app/models/`):

- Session-side App / Com / Org families: ~16 classes each → ~48 classes
- Actor-side User / Staff / Customer families: ~7 classes each → ~21 classes
- Bridges: `UserAppPreference`, `OperatorOrgPreference`
- Total: ~70 preference-related classes

### Cross-bubble code paths

- `app/controllers/concerns/preference/adoption.rb` — login-time sync between session-side and
  actor-side. Active for App↔User (same DB: `principal`) and Org↔Staff (currently cross-DB:
  `operator` ↔ `principal` until the staff_preference move completes). Customer is not in
  `Adoption`; Com→Customer sync goes through `Preference::Core#sync_to_resource_preference!` which
  currently crosses `setting` → `guest` (until the customer_preferences move completes).
- After both bubble-closure moves complete, `Preference::Adoption#resolve_cross_db_option_id`
  becomes dead code (no double-write path crosses bubbles anymore).
- `app/controllers/concerns/current_support.rb` — already reads via the unified
  `Actor::Preference` interface; this part is the doctrine-aligned target shape.

## Migration Strategy

This plan stages work to align with the doctrine without committing to specifics that belong to
other plans.

### Phase 1 — Inventory and dead-code identification

Scope: read-only audit. No schema or model deletion yet.

1. List all 70-ish preference classes and group by:
   - Has callers outside the preference subsystem (controllers / views / services / models)?
   - Has migrations that reference it?
   - Is it referenced only by `ClassRegistry` and tests?
2. Classify into:
   - **Active** — has external callers
   - **Internal-only** — only used inside the preference subsystem
   - **Unreferenced** — no callers (deletion candidate)
3. Identify bridge tables (`user_app_preferences`, `staff_org_preferences`) usage and whether they
   carry information the actor-side records do not already hold.

### Phase 2 — Class registry abstraction (depends on C3)

Scope: code-only. No schema changes. **Blocked on C3 plan.**

The 6-prefix × 8-subkey registry contains heavy duplication. C3 (a separate plan) will design how to
abstract `ClassRegistry` so prefix-symmetric code is written once.

This Phase tracks the cleanup that becomes possible once C3's abstraction lands:

- Remove duplicated audit / option / record class declarations that the abstraction makes redundant.
- Remove per-prefix branching in concerns (`Preference::Core`, `Preference::Adoption`,
  `Preference::Base`) that survives only because of registry duplication.

### Phase 3 — Actor-side schema decision (depends on B2)

Scope: schema design decision. **Blocked on B2 plan.**

User / Staff use normalized child tables; Customer uses denormalized columns. Whatever B2 decides —
normalize Customer, denormalize User/Staff, or wrap with an adapter — this Phase implements the
resulting cleanup, including dropping the redundant tables on the side that loses.

### Phase 4 — Adoption role decision (depends on B3)

Scope: behavior change. **Blocked on B3 plan.**

If B3 reduces or removes `Preference::Adoption`, this Phase removes its support infrastructure
(`adoptable_preference_class?`, `find_or_create_resource_preference!`, cross-DB option-id resolution
helpers) and any tables that exist only to support adoption.

### Phase 5 — Schema cleanup

Scope: schema-level. Run after Phases 2-4 settle.

- Drop tables that Phase 1 marked unreferenced and Phases 2-4 confirmed not needed.
- Drop bridge tables (`user_app_preferences`, `staff_org_preferences`) if Phase 1 confirmed no
  behavioral use.
- Remove per-DB columns that no longer have callers.

### Phase 6 — Activity / chronicle table review

Scope: separate-but-related. Optional.

`*_preference_chronicle*` and `*_preference_activity*` tables exist per session-side family. Decide
whether they should consolidate (and where), or stay per-bubble. Out of scope for the first pass;
tracked as a follow-up.

## Out of Scope (handled by other plans)

- DB consolidation of any kind (rejected by doctrine)
- Moving `customer_preferences` from `guest` to `setting`
  (`plans/backlog/customer-preferences-move-to-setting-db.md`)
- `ClassRegistry` redesign (C3 — separate plan)
- Actor-side schema asymmetry decision (B2 — separate plan)
- `Preference::Adoption` role re-evaluation (B3 — separate plan)
- Per-subdomain `Current` (jump / apex / sign) design (A5 — separate ADR)
- JWT `prf` claim format changes
- Cookie consent / token rotation behavior changes

## Blockers

- Phase 2 is blocked on the C3 plan (not yet authored).
- Phase 3 is blocked on the B2 plan (not yet authored).
- Phase 4 is blocked on the B3 plan (not yet authored).
- Phases 1, 5, 6 can proceed independently once approved.

## Acceptance Criteria

- [ ] Phase 1 inventory document committed (lists active / internal-only / unreferenced classes and
      bridge-table usage).
- [ ] Each soft bubble (`principal` / `operator` / `setting`) keeps its session-side and actor-side
      families and contains no preference-related dead tables.
- [ ] `guest` DB no longer contains preference tables (handled by separate plan; tracked here as a
      dependency).
- [ ] `Preference::ClassRegistry` no longer hard-codes 6 × 8 entries (handled by C3; tracked here as
      a dependency).
- [ ] Cookie consent, JWT `prf` claim integrity, and preference edit flows have regression coverage
      that survives the cleanup.
- [ ] No production read path bypasses `Actor::Preference` for preference values.

## References

- `adr/preference-soft-bubble-doctrine.md` — doctrine this plan obeys
- `plans/backlog/customer-preferences-move-to-setting-db.md` — com TLD bubble closure
- `plans/backlog/staff-preference-move-to-operator-db.md` — org TLD bubble closure
- `plans/backlog/gh578-preference-consolidation.md` — `Actor::Preference` runtime consolidation
  status
- `plans/backlog/current-support-integration-test-coverage.md` — `CurrentSupport` request-lifecycle
  test coverage
- `plans/archive/gh628-move-preferences-to-setting-db.md` — rejected predecessor (kept for
  traceability)
- `app/services/preference/class_registry.rb` — current registry
- `app/controllers/concerns/preference/adoption.rb` — current Adoption logic
- `app/controllers/concerns/current_support.rb` — current `Actor::Preference` resolver

## 2026-05-07 現状差分と改善として残すこと

この文書の DB 移動前提は現行ツリーより古い。

確認済み:

- `customer_preferences` 系は `setting` DB 側へ移動済み。
- `staff_preference_*` は `operator` 側に存在する。
- `Actor::Preference` は実装済みで、runtime read interface として使われている。

したがって、この文書は DB 移行計画ではなく、preference 周辺の重複削減計画として再スコープする。

残す改善:

- `UserAppPreference` / `OperatorOrgPreference` bridge の現在の呼び出し元と必要性を棚卸しする。
- `Preference::ClassRegistry` の 6 prefix
  x 多数 key の重複を、削除可能なものと抽象化すべきものに分ける。
- `AppPreference` / `ComPreference` / `OrgPreference` 自体は現時点では保持対象として扱う。
- 削除判断は `Actor::Preference` の回帰テスト、cookie consent、JWT `prf`
  claim のテストを先に固定してから行う。
