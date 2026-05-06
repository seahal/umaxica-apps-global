# Three-Engine Reframe Plan

## Status

Superseded (2026-04-17)

This plan is no longer the active direction.

The accepted follow-up decision restores a four-engine topology and renames the target engines to:

- `Identity`
- `Zenith`
- `Foundation`
- `Distributor`

Use `plans/active/four-engine-reframe.md` and `adr/four-engine-restoration-and-base-contract.md` for
current planning.

## Historical Summary

This document represented a temporary direction that would have merged the extracted `station` and
`press` code into one Regional engine. That direction has been abandoned.

The superseded target was:

- `Identity`
- `Global`
- `Regional`

The current target is:

- `Identity`
- `Zenith`
- `Foundation`
- `Distributor`

## Superseded Assumptions

The following assumptions in the old plan are no longer valid:

| Old assumption                                                          | Current direction                            |
| ----------------------------------------------------------------------- | -------------------------------------------- |
| `Global` is the canonical shared engine name                            | `Zenith` is the canonical name               |
| `Regional` is the canonical business engine name                        | `Foundation` is the canonical name           |
| `station` and `press` merge into one engine                             | `Foundation` and `Distributor` stay separate |
| `docs.*`, `help.*`, and `news.*` stay as Distributor-facing host labels | Distributor is normalized to `post.*`        |
| Regional-style public naming remains transitional                       | Foundation public naming is fixed to `base`  |

## Preserved Notes

Some principles from the old plan still remain useful and are carried forward into the four-engine
direction:

- database boundaries should remain explicit
- cross-engine SQL coupling should be avoided
- host and origin naming should be canonical and explicit
- Rails `main_app.*` remains a host-app route proxy and is not part of the Foundation helper rename

## Replacement Documents

- `adr/four-engine-restoration-and-base-contract.md`
- `plans/active/four-engine-reframe.md`
- `plans/active/dev-audience-tier.md`

## Do Not Use For Implementation

Do not use this document as the source of truth for:

- engine naming
- host ownership
- deploy modes
- route helper prefixes
- public ENV contracts

Those decisions are now owned by the replacement documents listed above.
