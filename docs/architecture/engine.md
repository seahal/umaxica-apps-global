# Engine and Database Boundary Design

## Background

The platform is organized into four Rails engines to enforce operational and code-level isolation:

- `Identity`
- `Zenith`
- `Foundation`
- `Distributor`

Each engine manages a specific set of domain responsibilities and maps to a dedicated database
group.

## Engine Roles

| Engine          | Namespace          | Host Labels / Entry Points       | Main responsibility                                 | Domain Database Group                   |
| --------------- | ------------------ | -------------------------------- | --------------------------------------------------- | --------------------------------------- |
| **Identity**    | `Jit::Identity`    | `sign.{app,org,com,dev,net}.*`   | Authentication, identity, token lifecycle           | `Activity`                              |
| **Zenith**      | `Jit::Zenith`      | `{app,org,com,dev,net}.*` (acme) | Shared shell, public sign entry, shared preferences | `Journal`                               |
| **Foundation**  | `Jit::Foundation`  | `base.{app,org,com,dev,net}.*`   | Business operations, contacts, and staff admin      | `Chronicle` family except `publication` |
| **Distributor** | `Jit::Distributor` | `post.{app,org,com,dev,net}.*`   | API and content delivery                            | `Publication`                           |

### Current Mapping

The existing extracted engines map to the canonical names as follows:

- `signature` -> `Identity`
- `world` -> `Zenith`
- `station` -> `Foundation`
- `press` -> `Distributor`

### Routing and Isolation

- **`isolate_namespace`**: Every engine uses `isolate_namespace` for code-level isolation.
- **Routing Proxies**: Cross-boundary navigation must use native Rails engine routing proxies. The
  mount alias becomes the route proxy (e.g., `identity.*`, `zenith.*`, `foundation.*`,
  `distributor.*`).
- **Host App Routes**: Engines must use `main_app.*` to link back to the host application.
- **Host Labels**: Different entry points (like `post.*` or `base.*`) are handled via host
  constraints in the routing layer of the respective engine.

### Request Context Boundary

Request-scoped current context is also owned by the engine boundary.

- `Identity` uses engine-local current context
- `Zenith` uses engine-local current context
- `Foundation` uses engine-local current context for `base.*`
- `Distributor` does not use shared `Current` by default

If `post.*` needs request metadata, it should use explicit helpers or small request-scoped value
objects instead of a shared mutable current container.

Engine-local `Current` remains an accepted pattern for request-scoped runtime state. This helps keep
actor, token, preference, and request metadata from leaking across concurrent requests in threaded
app servers such as Puma.

The implementation sequence for this boundary is still **TBC**. Any future `plans/` documents for
this work are temporary and may change.

### Canonical ENV Naming

Host and origin environment variables use this canonical format:

- `ENGINE_HOSTLABEL_AUDIENCE_URL`

Where:

- `ENGINE` is one of `IDENTITY`, `ZENITH`, `FOUNDATION`, `DISTRIBUTOR`
- `HOSTLABEL` is one of `SIGN`, `ACME`, `BASE`, `POST`
- `AUDIENCE` is one of `APP`, `ORG`, `COM`, `DEV`, `NET`

Examples:

- `IDENTITY_SIGN_APP_URL`
- `ZENITH_ACME_COM_URL`
- `FOUNDATION_BASE_ORG_URL`
- `DISTRIBUTOR_POST_APP_URL`
- `DISTRIBUTOR_POST_DEV_URL`
- `DISTRIBUTOR_POST_NET_URL`

Legacy names such as `SIGN_*`, `ACME_*`, `BASE_*`, `POST_*`, `MAIN_*`, `CORE_*`, and `DOCS_*` are
migration-source names only. They are not part of the target design.

## Database Ownership

Models are centralized in `app/models/` for shared domain definitions, but each engine is the
operational owner of a specific database group.

### Activity-owned databases (Identity Engine)

- `principal`, `operator`, `token`, `preference`, `guest`, `activity`, `occurrence`

### Journal-owned databases (Zenith Engine)

- `journal`, `notification`, `avatar`

### Foundation-owned databases

- `chronicle`, `message`, `search`, `billing`, `commerce`

### Distributor-owned databases

- `publication`

### Shared Infrastructure Databases

Infrastructure databases (`queue`, `cache`, `storage`, `cable`) are **duplicated per engine**. Each
engine deployment mode runs its own isolated instance of these services to prevent cross-engine
resource contention.

- **Solid Queue**: Separate job database and worker pool per engine.
- **Solid Cache**: Separate cache database per engine.

## Model and Database Policy

- **Centralized Models**: Shared model definitions stay in `app/models/` to ensure a single source
  of truth for domain logic.
- **Abstract Base Classes**: Database connectivity is partitioned via domain-specific base records
  (e.g., `ActivityRecord`, `JournalRecord`, `ChronicleRecord`) using Rails' `connects_to`.
- **Deployment-Mode Connectivity**: The `database.yml` and initialization logic use the
  `DEPLOY_MODE` environment variable to establish connections _only_ for the database group owned by
  the active engine.
- **Enforced Boundaries**: Attempting to access a model whose database is not owned by the active
  engine will result in a connection error, providing strict operational boundaries while
  maintaining a unified codebase.

## Deployment Modes

| Mode          | Engines mounted                           | Infrastructure Mode            |
| ------------- | ----------------------------------------- | ------------------------------ |
| `identity`    | Identity                                  | Identity-isolated instances    |
| `zenith`      | Zenith                                    | Zenith-isolated instances      |
| `foundation`  | Foundation                                | Foundation-isolated instances  |
| `distributor` | Distributor                               | Distributor-isolated instances |
| `development` | Identity, Zenith, Foundation, Distributor | All instances (local config)   |

## Related

- `adr/current-context-boundary-by-engine.md`
- `adr/four-engine-restoration-and-base-contract.md`
- `adr/engine-isolate-namespace-adoption.md`
- `docs/architecture/current_context.md`
- `plans/active/four-engine-reframe.md`
- `plans/active/foundation-distributor-db-boundary-plan.md`
