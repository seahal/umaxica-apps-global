# Public Entrypoints

## Purpose

This document records Rails entrypoints that do not require an already signed-in actor. Every
entrypoint is private by default unless its concrete controller/action declares
`AUTHENTICATION_MODE = :bare`, `:open`, or `:guest`.

Framework-owned routes such as Rails info pages, Action Mailbox, Active Storage, Turbo Native, and
development tooling are outside this application inventory. They are not public product contracts.

## Authentication Modes

| Mode        | Login required?         | Meaning                                                                                                                 |
| ----------- | ----------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `:bare`     | No                      | No application authentication lifecycle. Used for probes, static protocol metadata, content reads, and telemetry sinks. |
| `:open`     | No                      | Anonymous and authenticated actors may enter. Invalid credentials must still fail through authentication handling.      |
| `:guest`    | No for anonymous actors | Guest-only entry or ceremony flow. Signed-in actors are rejected or redirected by the flow.                             |
| `:private`  | Yes                     | Normal signed-in actor endpoint. Not public.                                                                            |
| `:deny_all` | Not reachable           | Fail-closed endpoint. Not public.                                                                                       |

## Documented Public Categories

The category IDs below are enforced by `test/unit/security/public_entrypoint_inventory_test.rb`.
Adding a new `:bare`, `:open`, or `:guest` route requires either fitting one of these categories or
updating this document and the test together.

| ID                                | Entrypoints                                                                                                                               | Notes                                                                                                                 |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `PUBLIC_ROOTS`                    | `GET /` on public app-owned hosts                                                                                                         | Thin landing, redirect, or content-root endpoints only.                                                               |
| `PUBLIC_HEALTH`                   | `GET /health`, `/health/liveness`, `/health/readiness`, `/health/startup`                                                                 | Rails marks these `:bare`; public edge traffic must remain blocked as described in `docs/operations/health-check.md`. |
| `PUBLIC_CSP_REPORTS`              | `POST /csp-violation-report`                                                                                                              | Unauthenticated browser telemetry intake only. Must not mutate actor/session/account state.                           |
| `PUBLIC_WELL_KNOWN`               | `GET /.well-known/jwks.json`, `GET /.well-known/openid-configuration`                                                                     | Protocol metadata and public keys.                                                                                    |
| `PUBLIC_ROBOTS_SITEMAPS`          | `GET /robots.txt`, `GET /sitemap.xml`                                                                                                     | Crawler metadata endpoints.                                                                                           |
| `PUBLIC_CONTENT_READ_APIS`        | Docs, Help, Info, and News roots plus `GET /api/v0/entries*`                                                                              | Read-only content surfaces; no create/update/delete authority.                                                        |
| `PUBLIC_PREFERENCE`               | `/preference*`                                                                                                                            | Login-independent preference read/write endpoints.                                                                    |
| `PUBLIC_WEB_EDGE`                 | `/web/v0/*` and `/edge/v0/*` public cookie, theme, DBSC, and token compatibility endpoints                                                | These are open protocol/transport endpoints, not general business APIs.                                               |
| `PUBLIC_OAUTH_OIDC_SSO`           | `/oauth*`, `/oidc*`, `/sso*`, and RP `/auth/*` protocol handoff paths                                                                     | Public protocol reachability does not bypass state, client, token, nonce, PKCE, or logout guards.                     |
| `PUBLIC_SIGN_IN_UP`               | `/sign/in*`, `/sign/up*`, and `/web/v0/in/*`                                                                                              | Credential and sign-up ceremonies. `:guest` routes reject already signed-in actors.                                   |
| `PUBLIC_SIGN_OUT`                 | `/sign/out*` and route-controller sign-out aliases                                                                                        | Logout pages are reachable without login; actual mutation stays guarded by current session state.                     |
| `PUBLIC_SOCIAL`                   | `/social*` and Base social ceremony continuation/completion routes                                                                        | Provider/state validation and ceremony records still own execution safety.                                            |
| `PUBLIC_AUTH_APP_SETTINGS_COMPAT` | Auth app `/settings/*` registration, birthdate, and session-revocation compatibility routes that currently declare `:open`                | Compatibility reachability only; authority must remain in the guarded settings/session services.                      |
| `PUBLIC_CORE_API`                 | Core `GET /api/v0/session` and `POST /api/v0/token/refresh`                                                                               | Core browser/BFF session-token boundary endpoints.                                                                    |
| `PUBLIC_PALM_API`                 | Palm `GET /api/v0/profile`                                                                                                                | Native bearer-token API entrypoint; actor login cookie is not required.                                               |
| `PUBLIC_AUTH_ORG_REDIRECTS`       | Auth org redirect-only compatibility paths such as `/accounts`, `/audit`, `/billing`, `/configuration`, `/iam`, `/support`, and `/system` | Redirect-only compatibility endpoints. Base owns authority.                                                           |
| `PUBLIC_SIDE_SETTINGS`            | Side `GET /settings`                                                                                                                      | Current Side settings shell entrypoint.                                                                               |

## Default Rule

Routes not covered above must require authentication or fail closed. In code, that means the route
must resolve to `:private` or `:deny_all`, and its concrete controller/action must declare that
classification locally.
