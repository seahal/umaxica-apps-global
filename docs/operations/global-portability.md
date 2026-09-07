# Global portability contract

This document is the operational contract for the Global repository. It keeps application settings
portable while leaving Compose responsible for infrastructure topology only.

## 1. Repository scope

This repository remains the Global application. Regional responsibilities are not split here and no
Regional repository is created by this work.

## 2. Runtime modes

The supported local modes are bare-metal Rails with Compose infrastructure and a Dev Container with
the same infrastructure. Both modes execute the same Rails application and frontend commands.

## 3. Configuration authority

Application configuration is the non-secret environment contract, not a Compose service definition.
`config/boot.rb` loads `.env` when present and otherwise `.env.example`; exported values always win.
Production never reads repository-local environment files.

## 4. Host contract

`.env.example` describes loopback PostgreSQL, Valkey, FakeCloud, Rails, Vite, URL, and identifier
settings. It contains development-only obvious placeholders, never production credentials.

## 5. Dev Container contract

`.env.devcontainer.example` is the same application contract with only topology-sensitive endpoints
changed to Compose service names. The tracked Dev Container overlay consumes it with `env_file`.

## 6. Compose boundary

`compose.yaml` provides PostgreSQL primary/replica, Valkey cache/rate-limit stores, FakeCloud, and
observability/tunnel topology. It has no Rails application service. The Dev Container overlay adds
only `core` and does not inline application variables.

## 7. PostgreSQL

Host-native Rails reaches the loopback-only writer and reader publications. Container Rails reaches
`primary` and `replica` through the backend network. The database names and connection roles remain
owned by `config/database.yml` and the environment contract.

## 8. Valkey

Cache and rate-limit stores remain physically separate. Host mode uses ports 6379 and 6380; the
container contract uses the two Compose service names. Neither store is a correctness datastore.

## 9. Object storage

FakeCloud is a disposable local S3-compatible endpoint on loopback for host tools and the
`fakecloud` service name for the container. Local access-key values are visibly fake test values.

## 10. Host exposure

Every published development port remains explicitly loopback-only. PostgreSQL and Valkey are not
reachable from the LAN, and no service uses host networking.

## 11. Secrets

No master key, secret key base, private key, bearer token, production database password, or cloud
credential belongs in either example file. Rails encrypted credentials and the ignored `.env` remain
provisioned out of band.

## 12. Frontend toolchain

Bun is the sole package manager and script runner. Vite, Vitest, Playwright, TypeScript, and the two
Rails frontend stacks remain intact. The package manager is pinned in `package.json` and the image.

## 13. Bare-metal startup

Use the following sequence from the repository root:

```bash
cp .env.example .env                 # optional; Rails falls back to the example
podman compose up -d                  # or docker compose up -d
bin/setup --skip-server
TMPDIR=/tmp/umaxica-vitest bin/dev
```

The Rails process is host-native; Compose supplies only the infrastructure services.

## 14. Dev Container startup

Open the repository in a Dev Container. The tracked Compose files and `.env.devcontainer.example`
resolve on a clean checkout. The post-create command installs Bundler and Bun dependencies and
prepares databases.

## 15. Database lifecycle

Local database, queue, cache, replica, and FakeCloud volumes are disposable. Destructive recreation
is acceptable during local recovery; never apply that procedure to a production volume.

## 16. Portability failure mode

Missing required values fail loudly through `ENV.fetch` or the existing typed configuration values.
The loader only fills absent local development values and never replaces explicit process settings.

## 17. URL contract

Private localhost aliases are used for direct local requests. Public URL values remain explicit and
are not inferred from a Compose project name or container hostname.

## 18. Dev Container filesystem

The repository remains a bind mount. Bundler, Bun cache, node modules, and nested Podman state use
named volumes so host ownership and source files remain stable across engines.

## 19. CI contract

CI installs Bun from the pinned setup action, installs from `bun.lock`, runs Bun scripts, and leaves
Rails database setup and tests explicit. The local CI helper follows the same commands.

## 20. Verification contract

The portability test is engine-free and checks the environment files, Compose boundary, host ports,
Dev Container inputs, and loader behavior. Runtime evidence records commands actually run.

## 21. Security review

The change does not alter cookie, session, authentication, authorization, CSRF, WebAuthn, OIDC, or
provider policy. It changes only how non-secret local configuration reaches the existing app.

## 22. Handoff decision

Regional cloning is not a task performed by this repository. The final evidence reports whether the
Global application is ready for that future clone and names any concrete verification blocker.
