# Global portability evidence — 2026-09-07

## Decision

**READY_FOR_REGIONAL_CLONE** for the application/configuration portability boundary. The repository
remains Global-only; this change does not create or copy a Regional repository. Container-engine
runtime coverage is limited by the shared Podman host stale network and port contention, recorded in
J below.

## A. Configuration authority — PASS

config/boot.rb loads the non-secret local contract through lib/local_environment.rb. An ignored .env
wins over .env.example, explicit process variables win over both, and production skips
repository-local files. .env.example is the host-native contract; .env.devcontainer.example changes
only container endpoints and runtime toggles.

Evidence: ruby -Itest test/tooling/global_portability_contract_test.rb — 5 tests, 56 assertions, 0
failures.

## B. Runtime modes — PASS (static)

Bare metal uses loopback endpoints and host-native Rails. Dev Container uses the tracked Compose
overlay, its env_file, and Compose DNS. The merged model rendered successfully with Podman Compose.
bin/setup --skip-server completed after installing Bundler/Bun and preparing databases.

## C. PostgreSQL multi-database topology — PASS

The environment examples cover development writer/reader publications in config/database.yml;
container test connections use primary, while host tests use loopback. RAILS_ENV=test bin/rails
db:prepare completed successfully against local PostgreSQL. Compose publishes database ports on
127.0.0.1 only.

## D. Solid Queue — PASS (configuration/schema)

Development uses Solid Queue backed by the dedicated queue database, with no queue replica in the
contract. db:prepare completed the queue database preparation. No Redis/Valkey endpoint is used for
job correctness.

## E. Valkey cache/rate-limit separation — PASS (static; host runtime contention noted)

The contract keeps separate CACHE_REDIS_URL and RATE_LIMIT_REDIS_URL values, using loopback ports
for host mode and separate Compose services for container mode. The cache container was healthy. The
rate-limit container could not be restarted during this run because a pre-existing container/network
held the host port; no application code or volume was changed.

## F. FakeCloud object storage — PASS

Both contracts use visibly fake credentials, distinct development buckets, and the FakeCloud
endpoint for their respective topology. The local endpoint returned status ok from
/_fakecloud/health.

## G. Setup and frontend isolation — PASS

bin/setup now installs the frozen Bun lockfile before db:prepare. bun install --frozen-lockfile, bun
run test (84 files, 1,020 tests), bun run check, and the production Vite build all passed. The
Importmap/Vite stack isolation test and affected authentication layout tests passed (15 tests, 412
assertions). The layout diffs remove an unsupported nonce keyword from javascript_importmap_tags;
they are compatibility fixes required by the 9fa35bc8f frontend migration, not topology churn.

## H. Security and secret policy — PASS

Tracked environment files contain no production secrets; .env remains ignored.

## I. Evidence and CI contract — PASS

Static portability tests and Bun CI checks passed.

## J. Full-suite and runtime caveat — NOT A PORTABILITY BLOCKER

The first full Rails run preceded restoration of the layout compatibility fix and failed on the
unsupported importmap nonce keyword. Affected tests passed after the fix. Container startup was
limited by stale Podman DNS state and an existing Valkey port collision; PostgreSQL, FakeCloud,
schema setup, focused Rails tests, and Bun checks were verified.

The corrected full Rails run also exposed one unrelated pre-existing
SignUpSequenceControllerSupportThresholdTest argument mismatch; it is outside this portability
change.

## Final verdict

READY_FOR_REGIONAL_CLONE
