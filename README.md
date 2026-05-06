[![CI](https://github.com/seahal/umaxica-app-jit/actions/workflows/integration.yml/badge.svg?branch=main)](https://github.com/seahal/umaxica-app-jit/actions/workflows/integration.yml)
![GitHub last commit (branch)](https://img.shields.io/github/last-commit/seahal/umaxica-app-jit/main)

# Umaxica App (JIT)

## Routing

- `app`: for end user
- `org`: controller panel
- `com`: brand page

Multi-domain Rails application for three audience surfaces. Routing is host-constrained, so domain
and subdomain matter in both development and production.

## Stack

- Ruby `4.0.2`
- PostgreSQL
  - Solid Queue
- Valkey/Redis
- Importmap + Stimulus + Turbo
  - Tailwind CSS via `tailwindcss-rails`
- Propshaft
- `pnpm` only for JavaScript linting/formatting tooling

## Frontend and Assets

This repository does not use a JavaScript bundler.

- JavaScript is served through `importmap-rails`
- Stimulus controllers live in `app/javascript/controllers`
- CSS is built by `tailwindcss-rails`
- Static assets are served by Propshaft

Useful commands:

```bash
bin/rails tailwindcss:watch     # Tailwind watch mode
bin/rails assets:precompile     # Production asset build
bin/rails assets:clobber        # Remove compiled assets
bin/importmap audit             # Audit pinned JS packages
```

## Local Setup

- Docker and Docker Compose
- Ruby `4.0.2`
- Bundler
- Node.js `20+`
- `pnpm@10.27.0`

Start the local stack, install dependencies, and boot the app:

```bash
docker compose up
bundle install
pnpm install
TRUSTED_ORIGINS=http://id.app.localhost:3000,http://id.org.localhost:3000 bin/setup
```

`TRUSTED_ORIGINS` is required for boot because WebAuthn origin validation fails fast when it is
missing.

`docker/core/env` defaults `TRUSTED_ORIGINS` to production sign domains, so override it locally in
your shell or dev env file, for example:

```bash
TRUSTED_ORIGINS=http://id.app.localhost:3000,http://id.org.localhost:3000
```

`bin/setup` installs Ruby gems, runs `bin/rails db:prepare`, clears logs and temp files, then starts
`bin/dev`. It does not install JavaScript packages, so run `pnpm install` first.

If dependencies are already installed, you can start development directly:

```bash
TRUSTED_ORIGINS=http://id.app.localhost:3000,http://id.org.localhost:3000 bin/dev
```

`bin/dev` runs `bin/rails db:prepare` unless `SKIP_DB_PREPARE=1`, then starts:

- `web`: Rails server on port `3000`
- `css`: `bin/rails tailwindcss:watch`
- `job`: `bin/jobs start`

## Development URLs

Modern browsers resolve `*.localhost` to `127.0.0.1`, so extra `/etc/hosts` entries are usually not
needed.

| Surface | URL                                        |
| :------ | :----------------------------------------- |
| Apex    | `http://{app,com,org}.localhost:3000`      |
| Sign    | `http://sign.{org,com,app}.localhost:3000` |
| core    | `http://www.{app,com,org}.localhost:3000`  |
| Docs    | `http://docs.{app,com,org}.localhost:3000` |

## Linting and Formatting

```bash
bundle exec rubocop
bundle exec rubocop -a
bundle exec erb_lint .
bundle exec erb_lint -a .
vp check
vp check --fix
```

Use `rubocop -a`, `erb_lint -a .`, and `vp check --fix` to apply auto-fixes where available.

## Testing

### Rails Tests

```bash
bundle exec rails test
COVERAGE=true bundle exec rails test
```

Coverage reports are written to `coverage/rails/`.

### JavaScript Tests

Run JavaScript tests with Vitest:

```bash
vp test
vp test --watch                            # Watch mode
pnpm test:coverage
```

JavaScript tests are located in `test/javascript/` and use Vitest with Vite Plus. Coverage reports
are written to `coverage/vite/`.

## Security and Quality Checks

```bash
bundle exec brakeman --no-pager
bundle exec bundler-audit check --update
bundle exec database_consistency
bin/importmap audit
pnpm audit
bin/debride
```

`bin/debride` is configured for Rails-aware analysis and can also be scoped to specific paths:

```bash
bin/debride app/services
DEBRIDE_MINIMUM=5 bin/debride
```

## Logging

Application logging is structured. Prefer event-style logging over ad hoc `Rails.logger` calls when
adding domain events or operational signals.

```ruby
Rails.event.notify("user.created", user_id: user.id)
Rails.event.tagged("auth") { Rails.event.notify("login.success", user_id: user.id) }
```

## Pre-commit Checks

Run the Lefthook pre-commit checks before committing:

```bash
lefthook run pre-commit
```

These checks cover formatting, linting, security audits, database consistency, and Rails tests.

## Troubleshooting

| Problem                                  | Fix                                                                                   |
| :--------------------------------------- | :------------------------------------------------------------------------------------ |
| Tailwind changes are not reflected       | Run `bin/rails assets:clobber` and restart `bin/dev` or `bin/rails tailwindcss:watch` |
| Tests fail because databases are missing | Run `bin/rails db:prepare`                                                            |
| `bin/dev` stops during boot              | Check `TRUSTED_ORIGINS` and database availability                                     |
| Credentials cannot be decrypted          | Use the shared Rails credentials key for this environment                             |

## Acknowledgement

- Secrets must stay in Rails credentials; do not commit plaintext secrets.
- WebAuthn origins are controlled by `TRUSTED_ORIGINS`.
- Public availability of this repository is not guaranteed permanently.
