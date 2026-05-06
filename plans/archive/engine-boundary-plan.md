# Engine Boundary Plan

## Status

Superseded (2026-04-17)

Use `adr/four-engine-restoration-and-base-contract.md` and `plans/active/four-engine-reframe.md`
instead.

## Summary

This analysis described a three-engine boundary model. The current accepted direction is a
four-engine model:

- `Identity`
- `Zenith`
- `Foundation`
- `Distributor`

## Reason For Supersession

- `Global` is now `Zenith`
- `Regional` is now split into `Foundation` and `Distributor`
- `base.*` and `post.*` are now separate public contracts
- five audience tiers (`app`, `org`, `com`, `dev`, `net`) are now part of the target design
