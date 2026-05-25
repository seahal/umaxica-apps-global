# ADR: Two-Base Authentication Mode Boundaries

**Status:** Accepted (2026-05-25)

## Context

The previous controller-boundary direction used `OpenController` plus surface-local
`ApplicationController` as the active lifecycle split, while older compatibility wrappers such as
`BareController`, `PrivateController`, and `GuestController` remained in the codebase. That left two
different ways to describe request access:

- controller inheritance for broad lifecycle behavior;
- controller/action metadata for the actual authentication classification.

This split makes open endpoints risky. An authentication-aware public endpoint can accidentally
inherit private, guest, or deny-all behavior from the wrong base, and a generated controller can
appear classified because it inherits a parent constant. The boundary should be explicit, auditable,
and fail closed.

## Decision

The current controller-base target is:

- `BareController`
- surface-local `ApplicationController`

`OpenController`, `PrivateController`, and `GuestController` are not semantic destination bases.
They may remain temporarily as compatibility wrappers while routes are migrated, but they are not
the request access contract.

`BareController` is for endpoints that do not use the application authentication machinery. Bare
endpoints must not read actor, session, preference, policy, authorization, verification, or
authentication state.

Surface-local `ApplicationController` owns the application request lifecycle for every endpoint that
uses authentication-aware request machinery. Endpoint access is declared by explicit
`AUTHENTICATION_MODE` metadata on the concrete controller or action, not by inheritance.

Supported authentication modes are:

| Mode        | Authenticated actor | Anonymous actor | Meaning                                                                       |
| ----------- | ------------------- | --------------- | ----------------------------------------------------------------------------- |
| `:bare`     | n/a                 | n/a             | No application authentication machinery.                                      |
| `:deny_all` | closed              | closed          | Default fail-closed mode for undeclared, disabled, or unclassified endpoints. |
| `:guest`    | closed              | open            | Guest entry flows such as sign in, sign up, and recovery.                     |
| `:private`  | open                | closed          | Normal authenticated endpoints.                                               |
| `:open`     | open                | open            | Endpoints reachable by anonymous and authenticated actors.                    |

`AUTHENTICATION_MODE` must be declared on the concrete controller or action. Inherited constants do
not count as declarations. Undeclared endpoints resolve to `:deny_all`.

Concerns must not change request behavior by registering callbacks when included. Surface-local
controller bases own callback registration and ordering explicitly.

## Authentication-Aware Open Endpoints

`:open` means anonymous and authenticated actors are both allowed. It does not mean authentication
failures may be ignored.

Open endpoints must distinguish:

- no credentials: continue as anonymous;
- valid credentials: build the authenticated `Actor` correctly;
- invalid, malformed, revoked, or expired credentials: use the normal authentication failure path,
  not anonymous fallback.

An endpoint should use `:open` only when authenticated personalization is required. Lightweight
infrastructure endpoints that do not use authentication machinery belong under `BareController` and
`:bare`.

## Authorization And Step-Up

Authentication mode does not authorize business access. Authorization remains a policy decision.

Step-up and authentication assurance are separate from controller inheritance and
`AUTHENTICATION_MODE`. Authorization policy is the runtime source of truth for required assurance
level, method set, and step-up scope for a concrete actor/action/resource. Challenge issuance,
redirect, return target handling, continuation, and ticket/session mutation belong to the step-up
gate.

Controller/action step-up metadata may exist only for inventory and CI assertions. Runtime
enforcement must not treat metadata as a second source of truth. If metadata and policy disagree,
the mismatch must fail closed rather than choosing the weaker requirement.

## Consequences

- `OpenController` is retired as a semantic target.
- `:deny_all` replaces the ambiguous `:restricted` authentication mode name.
- Route inventory must fail any route whose concrete controller/action lacks an explicit
  authentication declaration.
- Route inventory must fail inherited-only declarations.
- `:open` and `:bare` routes require careful inventory review because both are common fail-open
  vectors.
- Surface-local callback order remains the lifecycle source of truth.
