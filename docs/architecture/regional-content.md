# Regional And Global Delivery Boundary

> **Partially superseded by Identity Authority inversion:** The old RP vocabulary in this document
> must not be used to treat `acme/www` as an RP-only boundary. `acme/www` is now the Session, Token,
> Account, Preference, Authorization, and downstream-token Authority. `core`, `line`, and future
> downstream services trust acme-issued downstream tokens.

## Status

Regional RP delivery remains outside this repository's stable application architecture. Per
`adr/split-into-regional-and-global-repos.md`, regional RP delivery belongs to the separate regional
repository.

Read-only `docs`, `news`, and `help` content delivery is the explicit exception accepted by
`adr/read-only-content-surfaces-in-rails.md`. That v1 Rails implementation is public and read-only;
it does not restore the old regional engine, CMS editing, OIDC RP callbacks, preference writes, or
authenticated actor lifecycle.

## Boundary Map

| Boundary | Placement | Meaning                                                                      |
| -------- | --------- | ---------------------------------------------------------------------------- |
| `acme`   | Global    | Global RP surface for the primary application runtime.                       |
| `post`   | Global    | SNS-style or in-application posts. This does not mean docs/news publication. |
| `notice` | Global    | Push notification and notification-delivery behavior.                        |
| `core`   | Regional  | Regional RP surface, parallel in kind to `acme` but region-owned.            |
| `line`   | Regional  | Direct message behavior.                                                     |
| `docs`   | Regional  | Regional or locale-specific documentation delivery.                          |
| `news`   | Regional  | Regional or locale-specific news delivery.                                   |
| `help`   | Regional  | Regional or locale-specific help delivery.                                   |

`acme` and `core` are both RP surfaces, but they do not share repository ownership: `acme` remains
global, while `core` belongs to regional.

## Current Rule

Do not add regional RP or direct message implementation to this repository unless a current ADR
explicitly changes the repository boundary.

For `docs`, `news`, and `help`, only the v1 read-only Rails content delivery path described in
`adr/read-only-content-surfaces-in-rails.md` is current. Do not infer CMS editing, regional RP
behavior, OIDC callbacks, or preference writes from historical regional content material.

When a document says `post`, read the local context carefully:

- global `post` means SNS-style or in-application posts;
- docs/news/help publication remains regional unless a current ADR says otherwise.

Historical Foundation / Distributor content notes should be treated as migration background only.
