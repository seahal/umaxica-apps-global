# Split Into 4 Rails Engines

Supersedes: GitHub #553 (2-way Global/Local split)

## Motivation

The previous plan split the app into 2 deployment units (Global and Local). The new plan splits into
4 engines driven by **network topology and security requirements**:

1. **Permanent URL stability** — Authentication endpoints (passkeys, WebAuthn) require URLs that
   must never change. Isolating them limits blast radius of changes elsewhere.
2. **Closed network for content delivery** — Content delivery (docs, news, help) will use a
   Cloudflare VPN tunnel between Cloudflare Workers (Next.js) and AWS VPC (Rails). The Rails
   endpoints must not be accessible to the public internet.
3. **Global BFF flexibility** — The dashboard and API layer will evolve into a Next.js BFF. It needs
   freedom to change without affecting auth or content delivery.
4. **Regional business operations** — Contacts, management, and staff operations are regional and
   deploy per-region.

## Architecture Overview

```
                         ┌─────────────────────────────────┐
                         │         Public Internet          │
                         └──────┬──────────┬───────────────┘
                                │          │
                    ┌───────────▼──┐  ┌────▼────────────┐
                    │  signature   │  │     world        │
                    │ sign.{t}.*   │  │  {t}.*           │
                    │ Auth/Passkey │  │  Global BFF      │
                    │ Permanent URL│  │  Next.js backend  │
                    └──────────────┘  └─────────────────┘

                    ┌──────────────┐  ┌─────────────────┐
                    │   station    │  │     press        │
                    │ www.{t}.*    │  │ docs/news/help.* │
                    │ Regional ops │  │ Closed network   │
                    │ Contacts/Mgmt│  │ CF VPN tunnel    │
                    └──────────────┘  └─────────────────┘

                    {t} = {app, com, org}
```

| Engine        | Host pattern                    | Current domain | Network           | Purpose                                   |
| ------------- | ------------------------------- | -------------- | ----------------- | ----------------------------------------- |
| **signature** | sign.{app,com,org}.\*           | sign           | Public, permanent | Auth, passkeys, OIDC, social login        |
| **world**     | {app,com,org}.\*                | acme           | Public, flexible  | Global BFF, dashboard, settings           |
| **station**   | www.{app,com,org}.\*            | core           | Regional          | Contacts, management, staff admin         |
| **press**     | docs/news/help.{app,com,org}.\* | docs           | Closed (CF VPN)   | Content delivery, strictly internal Rails |

## Design Decisions

### Thin engines

Engines own routes, controllers, and views only. Models and database configuration stay in the main
app, shared by all engines.

**Rationale**: Models like User, Staff, Token are needed by every engine. Cross-engine model
references would create unnecessary complexity. Rails engines naturally reference host app models.

### No `isolate_namespace` initially

Controller namespaces stay unchanged (sign/, acme/, core/, docs/). This avoids mass-renaming
hundreds of controllers and their test files.

### Shared concerns

Authentication, authorization, rate limiting, preference, OIDC, and other cross-cutting concerns
stay in `app/controllers/concerns/`. Engines autoload them through an initializer.

**Exception**: Sign-specific concerns (29 files in `concerns/sign/`) move with the signature engine
because they have zero external consumers.

### Internal names preserved

Engine directory names are new (signature, world, station, press), but the controller namespace
paths inside each engine remain unchanged (sign/, acme/, core/, docs/). URLs do not change.

### DEPLOY_MODE

`Jit::Deployment` changes from 2 modes (global, local) to 4 modes (signature, world, station, press)
plus development (loads all). Each engine is conditionally mounted based on the mode.

### Content management routes

`core.rb` contains staff management routes for docs, news, and help content (lines 134-181). These
remain in **station** (not press), because they are staff admin operations on `www.org.*` hosts.
Press handles public-facing delivery only.

## Implementation Phases

### Phase 1: Scaffold and DEPLOY_MODE

Create 4 engine skeletons. Update `Jit::Deployment` from 2-mode to 4-mode. Update `config/routes.rb`
to mount engines. Remove old `engines/local/` skeleton.

### Phase 2: Extract press (docs)

Move docs routes, controllers (42), and views. Smallest domain, most isolated. Establishes the
extraction pattern.

### Phase 3: Extract world (acme)

Move acme routes, controllers (39), and views. Second smallest, straightforward BFF.

### Phase 4: Extract station (core)

Move core routes (including docs/news/help management routes), controllers (54), and views.
MissionControl::Jobs mount stays here.

### Phase 5: Extract signature (sign)

Move sign routes, controllers (163), views, and sign-specific concerns (29). Largest and most
security-critical. Benefits from all lessons learned.

### Phase 6: Cleanup

Remove leftover empty directories. Close tracking issues. Add ADR. Final validation.

## Database Classification

Models stay in the main app. For reference, the database scope classification:

| Scope      | Databases                                                                                 |
| ---------- | ----------------------------------------------------------------------------------------- |
| Global     | principal, operator, token, occurrence, avatar, activity, setting, commerce, notification |
| Regional   | guest, document, publication, behavior, message, search, billing, finder                  |
| Per-Deploy | queue, cache, storage                                                                     |

## Cross-Engine Route References

Before each extraction, audit controllers for named route helpers pointing to other domains. Replace
with URL configuration (e.g., `ENV["ZENITH_ACME_APP_URL"] + "/path"`) to ensure single-engine deploy
mode works.

## Related Issues

- Phase 1 (scaffold): #667
- Extract signature: #668
- Extract world: #669
- Extract station: #670
- Extract press: #671
- Supersedes: #553
