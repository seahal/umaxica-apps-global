# Regional And Global Delivery Boundary

## Status

Regional delivery is no longer part of this repository's stable application architecture. Per
`adr/split-into-regional-and-global-repos.md`, regional RP delivery and regional content surfaces
belong to the separate regional repository.

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

Do not add regional RP, direct message, or regional content delivery implementation to this
repository unless a current ADR explicitly changes the repository boundary.

When a document says `post`, read the local context carefully:

- global `post` means SNS-style or in-application posts;
- docs/news/help publication remains regional unless a current ADR says otherwise.

Historical Foundation / Distributor content notes should be treated as migration background only.
