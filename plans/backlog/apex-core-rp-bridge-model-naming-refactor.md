# Apex/Core RP Bridge Model Naming Refactor

## Status

Superseded by `adr/acme-rp-boundary-naming.md` and `plans/active/acme-rp-boundary-rename.md`.

## Summary

This backlog item previously deferred the naming refactor for RP bridge models that connect
Apex/Core RP behavior to the surface-owned IdP actors. The boundary naming decision is now accepted:
the RP-facing global Rails boundary is `Acme`, not `Apex`.

The current implementation plan does not include DB table, index, foreign key, constraint, schema,
or database connection renames. The inventory found no physical DB names containing `apex`.

## Current Direction

- Rename application/RP boundary names from `apex` / `Apex` to `acme` / `Acme`.
- Remove Core controller inheritance from the RP boundary; do not carry `Core::* < Apex::*` forward
  as `Core::* < Acme::*`.
- Keep runtime actor names fixed as `Client`, `Visitor`, and `Operator`.
- Preserve the DB boundary: app records stay under `app_zenith`, com records under `com_zenith`, and
  org records under `org_zenith`.
- Do not introduce compatibility aliases for old `apex` OIDC client ids or environment names unless
  implementation discovers a concrete local-data dependency.
- Keep DNS apex-domain terminology unchanged.

## Follow-Up

If bridge model names need further cleanup after the Acme rename, open a new plan that starts from
the accepted `Acme` vocabulary instead of the old `Apex/Core` framing.
