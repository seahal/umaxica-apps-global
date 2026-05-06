# Splitting the Rails Application into Separate Regional and Global Repositories (2026-04-25)

## Status

Accepted

## Context

This project has gone through several iterations of structural decomposition:

1. A "Fat Engine" architecture, with `Identity`, `Zenith`, `Foundation`, and `Distributor`
   implemented as Rails Engines mounted into a single root application (see
   `adr/engine-isolate-namespace-adoption.md`, `adr/four-engine-split.md`).
2. A migration away from fat engines toward four independent Rails applications under
   `apps/identity`, `apps/zenith`, `apps/foundation`, `apps/distributor` (see
   `adr/abolish-fat-engines-move-to-independent-apps.md`).

Both approaches struggled to converge. Engine isolation produced unmanageable nested namespaces,
view-path precedence issues, and Zeitwerk friction. The four-app split, while pragmatic, still
forced cross-app coordination on shared concerns (authentication, sessions, OIDC, account
preferences) and kept regional content surfaces (docs, news, help, and other locale/region-specific
delivery) tangled with the identity surface.

We also re-examined the deployment story. The identity / OIDC surface (historically served on the
`sign.*.{app,com,org}` hosts) and the primary application surface (the `www.*.{app,com,org}` hosts)
share most of their dependencies, data models, and authorization boundaries. The remaining surfaces
— region- and locale-specific content (docs, news, help, and similar) — have a different release
cadence, different operational requirements, and a different audience.

In parallel, we revisited the canonical hostname for the IdP. WebAuthn / FIDO2 binds credentials to
an RP ID (effectively the host), and a registered passkey cannot follow a later hostname change
without forcing every user to re-enroll. As long as no production passkeys exist on the old name,
this is the cheapest moment to settle on the canonical IdP hostname; later it becomes a user-visible
migration. We are taking that opportunity now.

(The base apex domain is intentionally not written out in this ADR because it may be renamed; the
decision is independent of the eventual brand name.)

## Decision

We will discontinue both the Rails Engine strategy and the four-app split strategy, and instead
divide the codebase into two independent repositories:

- **The global repository (this repository)** — a single, ordinary Rails application that hosts the
  IdP and the primary RP as one combined surface (`idp + rp = 1`). This repository absorbs:
  - the authentication / OIDC (IdP) surface, served on the `id.*.{app,com,org}` hosts, and
  - the main application (RP) surface, served on the `www.*.{app,com,org}` hosts,
  - together with the functionality previously labeled as the `Zenith` and `Signature` engines.

  Routing between the `id.*` and `www.*` hosts is unified inside this single application; whichever
  host is appropriate for a given action remains host-constrained, but they no longer live in
  separate apps or engines.

- **The regional repository (separate repository)** — hosts the regional / locale-specific surfaces
  (docs, news, help, and other regional delivery) that are not part of the global IdP + RP surface.
  Anything that does not belong to the global surface defined above is delegated there.

Concrete repository and domain names are intentionally omitted from this ADR because both are
subject to rename. The structural decision is independent of the eventual brand name: if the project
is rebranded or the repositories are renamed, this ADR still holds — only the names need to be
substituted at the operational layer (Git remotes, DNS, infrastructure config).

Concrete consequences for this repository:

- **No more Rails Engines.** `engines/` and the `Jit::<EngineName>::` namespace style are abolished.
  Code that previously lived in engines is folded into the standard Rails layout (`app/`, `lib/`,
  `config/`) of this single application.
- **No more `apps/<name>/` split.** The `apps/identity`, `apps/zenith`, `apps/foundation`, and
  `apps/distributor` plan from `adr/abolish-fat-engines-move-to-independent-apps.md` is superseded;
  this repository is one Rails app, not four.
- **Repository boundary, not engine boundary, is the isolation unit.** Domain isolation between the
  global surface and the regional surface is enforced by living in two separate repositories with
  their own deploys, dependencies, and ownership, not by in-process module boundaries.
- **Shared concerns inside this repo** — authentication, OIDC, sessions, account, workspace,
  preferences, avatars, billing — live as plain Rails code under `app/` and `lib/`, organized by
  ordinary Rails conventions rather than by engine or sub-app.

### IdP hostname: `sign.*` → `id.*`

We rename the canonical IdP host from `sign.*.{app,com,org}` to `id.*.{app,com,org}` as part of this
restructuring.

- **Why now.** WebAuthn binds credentials to an RP ID. Once production passkeys are registered
  against a hostname, changing that hostname breaks every existing credential and forces full
  re-enrollment. The combined repo split + IdP/RP unification is already a structural break, so this
  is the right moment — and effectively the last cheap moment — to fix the canonical name.
- **Why `id.*`.** It is shorter, conventional for an Identity Provider, and consistent with the
  `idp + rp = 1` framing: `id.*` is the IdP face, `www.*` is the RP face, and both are served by one
  application.
- **Operational follow-ups (deferred to implementation, not part of this ADR):** WebAuthn RP ID
  configuration, `TRUSTED_ORIGINS`, OIDC issuer / discovery URLs, OAuth client redirect URIs, CSP /
  Permissions-Policy entries, cookie domain settings, route host constraints, and CI / dev host
  fixtures all need to be updated to the new host. References to `sign.*` in code, fixtures, and
  docs are to be migrated to `id.*` during implementation.

## Consequences

- The migration target is materially simpler: one Rails application, one Gemfile, one Zeitwerk load
  path, one set of databases configured at the application level.
- Cross-cutting concerns between the IdP and the RP (sessions, CSRF, step-up auth, passkeys, OIDC
  claims) can be expressed directly without crossing engine or app boundaries.
- Code that was scaffolded under `engines/` or `apps/<name>/` for previous strategies is marked for
  removal once it has been ported into the standard Rails layout in this repository.
- Regional surfaces (docs, news, help, etc.) are no longer this repository's concern; requests for
  those surfaces are routed to the regional repository at the infrastructure layer.
- The IdP hostname is fixed to `id.*` _before_ any production passkey enrollment occurs, so the
  WebAuthn RP ID can be set once and never migrated. Any non-production / staging passkeys
  registered against the old `sign.*` host are considered disposable.
- Earlier ADRs that assume an engine-based or four-app structure
  (`adr/engine-isolate-namespace-adoption.md`, `adr/four-engine-split.md`,
  `adr/four-engine-restoration-and-base-contract.md`,
  `adr/four-app-wrapper-runtime-and-root-retirement.md`,
  `adr/four-app-solid-cache-and-solid-queue.md`,
  `adr/abolish-fat-engines-move-to-independent-apps.md`,
  `adr/rails-way-engine-architecture-restoration.md`, `adr/three-engine-consolidation.md`,
  `adr/current-context-boundary-by-engine.md`) are superseded by this decision to the extent that
  they prescribe an engine layout or a multi-app split inside a single repository. Their
  domain-level reasoning (e.g. which data belongs together, which boundaries matter) remains useful
  as background, but the structural prescriptions no longer apply.
