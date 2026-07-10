# Distributor Help Surface Plan

## Status

Active draft (2026-04-17)

## Summary

Keep `help` as a reserved Distributor content family while `docs/news` are implemented first.

Fixed constraints:

- `help` is separate from `docs/news`
- inquiry/contact is owned by Foundation `base.*`
- `help` has no v1 homepage requirement
- `help` has no immediate content implementation requirement
- future `help` editing belongs only to the `base.org.*` staff CMS surface
- future `help` content should remain compatible with the Distributor delivery model

## Current Position

For the current phase, `help` should remain reserved but should not drive feature work.

What to preserve now:

- keep `help` as a future Distributor content family
- keep `help` out of inquiry/contact controller work
- keep `help` independent from `docs/news` implementation

What not to build now:

- no homepage requirement
- no public FAQ API requirement
- no taxonomy requirement
- no staff CMS controller implementation requirement

## Future Implementation Rules

When `help` becomes an active implementation target:

- editing must happen only from the `base.org.*` staff CMS surface
- delivery should happen on `post.*`
- content should follow a document-like editorial flow
- `help` stays separate from Foundation inquiry/contact behavior

## Test Plan

Current phase:

- `help` remains reserved as a Distributor family
- `help` is not used by inquiry/contact work
- `docs/news` work does not introduce accidental coupling to `help`

## Assumptions

- leaving `help` inactive for now is acceptable
- the current need is to preserve a safe direction, not to ship a `help` feature immediately
