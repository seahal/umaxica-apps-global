# Foundation / Distributor Database Boundary Plan

## Status

Active draft (2026-04-18)

## Summary

Define the database ownership split between Foundation and Distributor under the four-app target.

## Ownership Decision

| Engine      | Primary ownership                                       |
| ----------- | ------------------------------------------------------- |
| Foundation  | `chronicle`, `message`, `search`, `billing`, `commerce` |
| Distributor | `publication`                                           |

## Naming Decision

Foundation detailed record naming is fixed as:

- use `chronicle`
- do not use `behavior` as a target model or DB family name

Global naming remains open until implementation pressure makes it necessary.

## Rules

- Foundation is the write owner for non-publication business stores
- Distributor is the delivery and publication owner
- if Foundation edits publication data, do so through an explicit admin boundary
- define whether each write creates a Foundation chronicle event, a Distributor publication event,
  or both before implementation starts
- use separate logical database ownership, not schema-level ambiguity
- add a static guard test for non-owner write usage before persistence refactors begin

## Acceptance Criteria

- `publication` ownership is documented as Distributor-facing
- non-publication business stores remain Foundation-facing
- active plans do not describe Distributor as owning the full chronicle group
- active plans do not use `behavior` as the Foundation target name

## Related

- `plans/active/model-layer-audit-evidence-checklist.md`
- `plans/active/four-engine-migration-sequence.md`
