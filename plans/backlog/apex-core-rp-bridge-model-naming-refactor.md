# Apex/Core RP Bridge Model Naming Refactor

## Summary

Defer the naming refactor for the RP bridge models that connect Apex/Core RP behavior to the
surface-owned IdP actors. The current `CoreAppClientBridge`, `CoreComVisitorBridge`, and
`CoreOrgOperatorBridge` models remain in place for now.

## Proposed Direction

- Decide one surface/RP naming grammar before renaming models or tables. The current candidates are
  `CoreAppClientBridge` style versus a surface-first style such as `AppCoreClientBridge`.
- Keep the runtime actor names fixed as `Client`, `Visitor`, and `Operator`; do not introduce
  compatibility names for `User`, `Customer`, or `Staff`.
- Preserve the DB boundary: app records stay under `app_zenith`, com records under `com_zenith`,
  and org records under `org_zenith`.
- Clarify whether `*Identity` should allow one row per actor per RP audience. The current
  `source_record_id` uniqueness makes multi-RP claim mappings a schema decision, not only a model
  rename.

## Test Plan

- Add model tests for the final bridge names, default RP metadata, public IDs, and actor association.
- Add callback tests proving Apex and Core both resolve actors through the shared RP provisioning
  path.
- Add migration tests or schema verification for any table/index rename matrix.

## Assumptions

- This is a later cleanup; current behavior should continue to use the existing `Core*Bridge` names.
- Any table/index rename must be handled as a separate reversible migration plan.
