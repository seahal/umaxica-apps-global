# Engine-based Global/Local Separation Design

## Background

This application serves multiple domains across regions (jp, us, etc.). The system needs to be split
into two deployment units:

- **Global**: Worldwide single instance (authentication, preferences)
- **Local**: Per-region instance (content, billing, regional services)

These two units must be **completely isolated** at the routing level. A Global deployment must not
expose any Local endpoints, and vice versa.

## Database Classification

Each database is classified into one of three deployment scopes. These are documented as comments on
each base record file (`app/models/*_record.rb`).

### Global (single worldwide instance)

| Database       | Base Record          | Purpose                |
| -------------- | -------------------- | ---------------------- |
| `principal`    | `PrincipalRecord`    | User identity          |
| `operator`     | `OperatorRecord`     | Staff management       |
| `token`        | `TokenRecord`        | Authentication tokens  |
| `preference`   | `PreferenceRecord`   | User/staff preferences |
| `occurrence`   | `OccurrenceRecord`   | Rate limiting          |
| `avatar`       | `AvatarRecord`       | User profiles          |
| `activity`     | `ActivityRecord`     | Audit logs             |
| `notification` | `NotificationRecord` | Notifications          |

### Local (per-region isolated instance)

| Database   | Base Record      | Purpose         |
| ---------- | ---------------- | --------------- |
| `document` | `DocumentRecord` | CMS documents   |
| `news`     | `NewsRecord`     | News/blog posts |
| `guest`    | `GuestRecord`    | Guest contacts  |
| `behavior` | `BehaviorRecord` | User behavior   |
| `message`  | `MessageRecord`  | Messages        |
| `finder`   | `FinderRecord`   | Search (finder) |
| `search`   | `SearchRecord`   | Search          |
| `billing`  | `BillingRecord`  | Billing         |

### Per-Deploy (each deployment has its own)

| Database  | Purpose               |
| --------- | --------------------- |
| `queue`   | SolidQueue jobs       |
| `storage` | ActiveStorage files   |
| `cable`   | ActionCable WebSocket |

Per-Deploy databases exist in both Global and Local deployments independently. They are
infrastructure concerns, not business data.

## Controller / Route Classification

### Global (sign, apex)

| Route file | Domain purpose                             | Hosts (dev)                                       |
| ---------- | ------------------------------------------ | ------------------------------------------------- |
| `sign.rb`  | Authentication (sign-in/up, MFA, passkeys) | `id.app.localhost`, `id.org.localhost`            |
| `apex.rb`  | Dashboard shell & preferences              | `app.localhost`, `org.localhost`, `com.localhost` |

### Local (core, docs, news, help)

| Route file | Domain purpose   | Hosts (dev)                                                   |
| ---------- | ---------------- | ------------------------------------------------------------- |
| `core.rb`  | Main app backend | `www.app.localhost`, `www.org.localhost`, `www.com.localhost` |
| `docs.rb`  | Documentation    | `docs.com.localhost`                                          |
| `news.rb`  | News/blog        | news domains                                                  |
| `help.rb`  | Help system      | help domains                                                  |

## Target Architecture: Two Rails Engines

### Directory Structure

```
workspace/
├── app/                              # Host app (shared foundation only)
│   ├── models/                       # All models (shared by both engines)
│   │   ├── application_record.rb
│   │   ├── principal_record.rb       # Global
│   │   ├── document_record.rb        # Local
│   │   └── ...
│   ├── controllers/
│   │   └── application_controller.rb # Base controller only
│   ├── helpers/
│   ├── services/
│   └── views/layouts/shared/         # Shared layouts
│
├── engines/
│   ├── global/                       # Global Engine
│   │   ├── app/
│   │   │   ├── controllers/
│   │   │   │   ├── sign/             # sign.app, sign.org
│   │   │   │   └── apex/             # apex.app, apex.org, apex.com
│   │   │   └── views/
│   │   │       ├── sign/
│   │   │       └── apex/
│   │   ├── config/
│   │   │   └── routes.rb             # sign + apex routes
│   │   ├── lib/global/
│   │   │   └── engine.rb
│   │   └── global.gemspec
│   │
│   └── local/                        # Local Engine
│       ├── app/
│       │   ├── controllers/
│       │   │   ├── core/
│       │   │   ├── docs/
│       │   │   ├── news/
│       │   │   └── help/
│       │   └── views/
│       │       ├── core/
│       │       ├── docs/
│       │       ├── news/
│       │       └── help/
│       ├── config/
│       │   └── routes.rb             # core + docs + news + help routes
│       ├── lib/local/
│       │   └── engine.rb
│       └── local.gemspec
│
├── config/
│   ├── routes.rb                     # Host: mounts engines only
│   └── database.yml
└── Gemfile
```

### Host Routes (`config/routes.rb`)

The host app does not define business routes. It only mounts the appropriate engine based on the
deployment mode:

```ruby
Rails.application.routes.draw do
  post "/csp-violation-report", to: "csp_violations#create"

  if Jit::Deployment.global?
    mount Global::Engine, at: "/"
  end

  if Jit::Deployment.local?
    mount Local::Engine, at: "/"
  end
end
```

### Engine Definitions

**Global Engine** (`engines/global/lib/global/engine.rb`):

```ruby
module Global
  class Engine < ::Rails::Engine
    isolate_namespace Global
  end
end
```

**Local Engine** (`engines/local/lib/local/engine.rb`):

```ruby
module Local
  class Engine < ::Rails::Engine
    isolate_namespace Local
  end
end
```

### Engine Routes

**Global** (`engines/global/config/routes.rb`):

```ruby
Global::Engine.routes.draw do
  # sign routes (from current config/routes/sign.rb)
  # apex routes (from current config/routes/apex.rb)
end
```

**Local** (`engines/local/config/routes.rb`):

```ruby
Local::Engine.routes.draw do
  # core routes (from current config/routes/core.rb)
  # docs routes (from current config/routes/docs.rb)
  # news routes (from current config/routes/news.rb)
  # help routes (from current config/routes/help.rb)
end
```

### Gemfile

```ruby
gem "global", path: "engines/global"
gem "local",  path: "engines/local"
```

### Deployment Mode (`lib/jit/deployment.rb`)

```ruby
module Jit
  module Deployment
    def self.mode
      ENV.fetch("DEPLOY_MODE", "development")
    end

    def self.global?
      mode.in?(%w[global development])
    end

    def self.local?
      mode.in?(%w[local development])
    end
  end
end
```

| `DEPLOY_MODE` | Global Engine | Local Engine | Use case                |
| ------------- | ------------- | ------------ | ----------------------- |
| `global`      | mounted       | NOT loaded   | Production (worldwide)  |
| `local`       | NOT loaded    | mounted      | Production (per-region) |
| `development` | mounted       | mounted      | Local development       |

## Model Sharing

Models remain in the host app (`app/models/`), not in either engine. Both engines access models
through the host:

- **Global Engine** reads/writes Global models directly (PrincipalRecord, TokenRecord, etc.)
- **Local Engine** reads/writes Local models directly (DocumentRecord, NewsRecord, etc.)
- **Local Engine** reads Global models via read replicas (e.g., `principal_replica` for user lookup)

`isolate_namespace` isolates controllers, routes, and views, but models are shared through the host
app. This is intentional — it avoids model duplication and keeps DB connections centralized.

## Cross-Region Database Access

Local deployments need read access to Global databases (e.g., looking up user info from
`principal`). This is handled at the infrastructure level:

- **Aurora Global Database** (or equivalent) provides low-latency read replicas in each region
- No application-level caching is needed; the DB layer handles cross-region replication
- Local deployments connect to the regional read replica of Global databases via `database.yml`
  environment variables

## Shared Resources

The following stay in the host app and are available to both engines:

- All models (`app/models/`)
- Shared concerns (`app/controllers/concerns/`, `app/models/concerns/`)
- Services (`app/services/`)
- Helpers (`app/helpers/`)
- Shared layouts and partials (`app/views/layouts/shared/`)
- Mailers, jobs, and other cross-cutting concerns
- Configuration (credentials, initializers)

## Migration Path

This is a significant refactoring. A phased approach is recommended:

### Phase 1: Deployment Mode Switch (low risk)

Add `Jit::Deployment` module and gate existing routes with `global?` / `local?` checks. No file
moves. This alone enables separated deployments.

### Phase 2: Extract Engines (high effort)

Move controllers and views into engine directories. Update route files. Adjust tests. This provides
clean code boundaries but is a large change.

### What to Watch Out For

- **Concerns shared between Global and Local controllers**: Keep in host `app/controllers/concerns/`
- **Helper methods**: Keep shared helpers in host, engine-specific helpers in the engine
- **Asset pipeline**: Each engine can have its own assets, or share via the host
- **Test organization**: Engine tests can live in `engines/global/test/` and `engines/local/test/`,
  or remain in the host's `test/` directory during transition
