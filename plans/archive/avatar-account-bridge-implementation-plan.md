# Avatar / Account Bridge Implementation Plan

> **Superseded by GitHub issue #831 (2026-07-29):** This plan is deactivated. The GitHub issue is
> authoritative for current status and scope. This file is retained under `plans/archive/` for
> historical context only.

Status: active implementation plan

## Goal

Record the bridge strategy for `Avatar -> Account` and sequence the future implementation work
without changing code in this planning step.

## Scope Guard

- Docs-only PR freeze.
- No application code changes.
- No migrations.
- No route changes.
- No model changes.
- No controller changes.
- No service changes.
- No policy changes.
- No test changes.

## Accepted Direction

- Use an explicit bridge table for `Avatar` / `Account`.
- Keep `AvatarAssignment` as authority and posting-role infrastructure.
- Keep `AvatarMembership` as temporal / participation / history infrastructure.
- Keep `Member` as a legacy bridge until a separate cleanup phase.
- Keep `actor_id` ambiguous for now.
- Phase 1 is app only.
- Phase 1 Account model is `Persona`.
- Phase 1 bridge is `Avatar <-> Persona`.
- `com` remains Avatar-ineligible.
- `org` remains a later candidate through `Agent`.
- `AvatarPersonaBinding` already exists in the avatar database.

## Recommended Technical Shape

- Bridge table name: `AvatarPersonaBinding`.
- Bridge semantics: additive binding with `assigned_at` / `revoked_at`.
- Active uniqueness: one active row per `Avatar` / `Persona` pair.
- Current DB placement: avatar database.
- `app_zenith` is a historical candidate only; do not plan a duplicate table there.
- Cross-DB foreign keys: avoid them.

## Recommended PR Split

### PR 1: Docs reconciliation

- Update the ADR, architecture summary, and this plan so they match current implementation facts.
- Record the current avatar-database placement.
- Remove any remaining implication that a new additive migration must create the bridge table.

### PR 2: Existing binding verification

- Verify the current `AvatarPersonaBinding` table shape and the existing bootstrap-created row.
- Confirm the unique constraints and bootstrap expectations match runtime behavior.
- No schema changes.

### PR 3: Read-only data audit / orphan report

- Audit existing `Avatar`, `Member`, `Persona`, and `ClientIdentity` records.
- Confirm whether any orphan or mismatch cases exist for the current binding model.
- Keep this read-only.

### PR 4: Schema hardening if needed

- Harden the existing table only if audit results show a concrete need.
- Do not relocate the table.
- Do not add a duplicate table in `app_zenith`.

### PR 5: Bootstrap idempotency / regression hardening

- Preserve the current bootstrap path that creates one binding.
- Add or tighten regression coverage around idempotency and `RecordNotUnique` behavior if required.

### PR 6: Read-path wiring / policy

- Add Avatar -> Persona read path.
- Add Persona -> Avatar read path.
- Connect bridge revocation to last admin / owner protection where needed.

### PR 7: Legacy cleanup planning

- Keep `Member` cleanup out of scope for the bridge rollout.
- Document the remaining `actor_id` ambiguity cleanup work.

## Open Questions

- Should any future relocation be made from the avatar database to `app_zenith`, or should the
  current placement remain permanent?
- Which existing bootstrap records can be matched deterministically without `actor_id`?
- At what point should last admin / owner protection be enforced in policy?

## Verification Expectations

- Do not merge implementation PRs without focused tests for idempotency, uniqueness, and revocation
  behavior.
- Do not treat bridge creation as complete until both read paths and policy connection points are
  documented.

## Related

- `adr/avatar-account-bridge-boundary.md`
- `docs/architecture/avatar-account-bridge.md`
- `docs/architecture/sns-subject-resource-decision-record.md`
