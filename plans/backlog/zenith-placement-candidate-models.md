# Zenith Placement Candidate Models

## Context

`docs/architecture/database-boundaries.md` defines `zenith` as the surface-owned database for
Zenith/RP-facing account, identity binding, and local projection state.

This note lists models that currently live in `principal` or `ticket` databases but may be better
treated as Zenith/RP-side state. It is an audit list, not an approved migration plan.

## Already In Zenith

These are already placed in the matching `*_zenith` database and are the current naming baseline.

| Surface | Account           | Identity binding   | State                   |
| ------- | ----------------- | ------------------ | ----------------------- |
| app     | `ClientAccount`   | `ClientIdentity`   | `ClientIdentityState`   |
| org     | `OperatorAccount` | `OperatorIdentity` | `OperatorIdentityState` |
| com     | `VisitorAccount`  | `VisitorIdentity`  | `VisitorIdentityState`  |

## Moved In Current Refactor

These models looked like durable RP/Zenith-side projections rather than authenticated-principal
credentials or short-lived login tickets, and were moved to Zenith in the current refactor. The
source principal tables were not dropped; cleanup/backfill is a separate migration plan.

| Current model                        | Source table                      | New table                                           | Target       | Why                                                                                                                                                                                      |
| ------------------------------------ | --------------------------------- | --------------------------------------------------- | ------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ClientProfile`                      | `app_principal.clients`           | `app_zenith.client_profiles`                        | `app_zenith` | Looks like an app-side client/profile projection, not the authenticated `Client` principal itself. It was previously named `VisitorAccount`, which made the RP/account intent ambiguous. |
| `VisitorAccountStatus`               | `app_principal.client_statuses`   | `app_zenith.client_profile_statuses`                | `app_zenith` | Reference state for `ClientProfile`; moved with that projection.                                                                                                                         |
| `OperatorWorkspaceAccount`           | `org_principal.operator_accounts` | `org_zenith.operator_workspace_accounts`            | `org_zenith` | Durable workspace/department-side account projection linked to `Operator`; not a credential or the authenticated principal row itself.                                                   |
| `OperatorWorkspaceAccountMembership` | `org_principal.staff_operators`   | `org_zenith.operator_workspace_account_memberships` | `org_zenith` | Join state for `OperatorWorkspaceAccount`; moved with it.                                                                                                                                |

## Resolved Separately

| Current model   | Source table                   | New table                       | Target          | Why                                                                                                                                                                  |
| --------------- | ------------------------------ | ------------------------------- | --------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `VisitorBanner` | `app_principal.client_banners` | `com_principal.visitor_banners` | `com_principal` | Banner state follows the authenticated `Visitor` surface actor, matching `ClientBanner` and `OperatorBanner`. The legacy `client_banners` table is not dropped here. |

## Medium Candidates

These are not session tokens themselves, but they represent durable OIDC/RP connection state. They
could reasonably stay in `ticket` if `ticket` continues to mean all OIDC grant persistence, but they
also fit the `zenith` definition if Zenith owns RP-client relationships.

| Current model            | Current DB   | Current table              | Candidate target | Why                                                                   |
| ------------------------ | ------------ | -------------------------- | ---------------- | --------------------------------------------------------------------- |
| `ClientOidcConnection`   | `app_ticket` | `user_oidc_connections`    | `app_zenith`     | Long-lived per-actor/per-RP-client connection; not a one-time ticket. |
| `OperatorOidcConnection` | `org_ticket` | `staff_oidc_connections`   | `org_zenith`     | Same pattern as `ClientOidcConnection`.                               |
| `VisitorOidcConnection`  | `com_ticket` | `visitor_oidc_connections` | `com_zenith`     | Same pattern as `ClientOidcConnection`.                               |

## Keep Outside Zenith Unless Semantics Change

These currently look correctly placed outside Zenith.

| Model family                                                                            | Current DB role | Reason                                                                                            |
| --------------------------------------------------------------------------------------- | --------------- | ------------------------------------------------------------------------------------------------- |
| `ClientToken`, `OperatorToken`, `VisitorToken` and token reference tables               | `*_ticket`      | Session/refresh/DBSC/DPoP token persistence is ticket state, not durable RP projection.           |
| `ClientAuthorizationCode`, `OperatorAuthorizationCode`, `VisitorAuthorizationCode`      | `*_ticket`      | Short-lived authorization-code grant tickets.                                                     |
| `ClientStepUpSession`, `OperatorStepUpSession`, `VisitorStepUpSession`                  | `*_ticket`      | Session-bound verification state.                                                                 |
| `ClientSecret`, `OperatorSecret`, `VisitorSecret` and status/kind tables                | `*_principal`   | Actor credential state.                                                                           |
| `ClientPasskey`, `OperatorPasskey`, `VisitorPasskey` and status tables                  | `*_principal`   | Actor credential state.                                                                           |
| `ClientEmail`, `OperatorEmail`, `VisitorEmail` and status tables                        | `*_principal`   | Actor contact and recovery identity state.                                                        |
| `ClientTelephone`, `OperatorTelephone`, `VisitorTelephone` and status tables            | `*_principal`   | Actor contact and recovery identity state.                                                        |
| `ClientPreference`, `OperatorPreference`, `VisitorPreference` and child preference rows | `*_principal`   | `docs/architecture/database-boundaries.md` explicitly keeps actor-local preferences in principal. |

## Open Decisions

- Decide whether OIDC connection rows are durable RP relationships (`zenith`) or ticket-owned grant
  state (`ticket`).
- If any strong candidate moves, write a table-by-table migration plan before implementation. The
  migration must avoid destructive operations and handle cross-database associations explicitly.
