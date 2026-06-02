# Acme RP Boundary Rename

> **Deprecated by Identity Authority inversion:** `acme/www` now owns Session, Token, Account,
> Preference, Authorization, and downstream-token authority. `sign/id` is ceremony-only. Physical DB
> movement is out of scope. Implementation details in this plan must not be used to reintroduce
> sign-side authority.

## Summary

Rename the RP-facing global Rails boundary from `acme` / `Acme` to `acme` / `Acme`.

This plan implements `adr/acme-rp-boundary-naming.md`. The rename covers application code,
configuration, routing, OIDC client ids/audiences, i18n keys, tests, and documentation. It does not
require DB schema changes because the inventory found no `acme` table, column, foreign key, index,
constraint, migration, schema dump, structure SQL, or database connection names.

## Scope

Must rename:

- `config/routes/acme.rb` to `config/routes/acme.rb`.
- `draw :acme` to `draw :acme`.
- route scope `module: :acme, as: :acme` to `module: :acme, as: :acme`.
- generated route helper references from `acme_*` to `acme_*`.
- `app/controllers/acme/**` to `app/controllers/acme/**`.
- `Acme::*` constants to `Acme::*`.
- `app/views/acme/**`, `app/views/layouts/acme/**`, and `app/assets/stylesheets/acme/**` to `acme`.
- `layout "acme/..."` and `render template: "acme/..."` references to `acme`.
- `Core::* < Acme::*` inheritance by giving Core its own `ActionController::Base`-backed controller
  bases. Do not replace this with `Core::* < Acme::*`.
- OIDC client ids `acme_app`, `acme_com`, and `acme_org` to `acme_app`, `acme_com`, and `acme_org`.
- OIDC audiences such as `umaxica-acme-app` to `umaxica-acme-app`.
- ENV/config names `ACME_SERVICE_URL`, `ACME_CORPORATE_URL`, `ACME_STAFF_URL`, `ACME_NETWORK_URL`,
  and `ACME_DEVELOPER_URL` to `ACME_*`.
- i18n keys under `acme.*` to `acme.*`.
- exposed RP boundary labels such as `Acme preferences` to `Acme preferences`.
- test paths, class names, test names, assertions, and fixtures that use the RP boundary name.
- current docs and active/backlog plans that describe the RP boundary.

Must not rename:

- DNS apex-domain terminology.
- `apex-scoped` cookie domain language that describes `.example.com` style cross-subdomain scope.
- `example.com`, `app.example.com`, `org.example.com`, and similar DNS test hosts.
- archived plans solely for historical accuracy, unless a current doc links to them as guidance.

## DB Impact

No DB schema migration is planned.

The inventory found no `acme` names in:

- table names
- column names
- foreign key names
- index names
- constraints
- migration file names
- schema dumps
- structure SQL
- `config/database.yml`

If implementation later discovers persisted data values containing OIDC `audience` or `client_id`
values such as `acme_app`, handle that as an application-data compatibility decision, not as a
schema rename. The current deployment state does not require staging or production compatibility for
old OIDC names.

## Routing And API Impact

The URL paths can remain stable. The public paths are currently `/`, `/health`, `/robots.txt`,
`/sitemap.xml`, `/web/v0/*`, `/edge/v0/*`, `/auth/callback`, `/sso/*`, `/accounts`, `/jobs`, and
`/db`; they do not expose `/acme` path segments.

The Rails helper and controller namespace interface changes:

- `acme_app_*` to `acme_app_*`
- `acme_com_*` to `acme_com_*`
- `acme_org_*` to `acme_org_*`
- `acme_network_*` to `acme_network_*`
- `acme_developer_*` to `acme_developer_*`

Because route helpers are widely referenced from sign, preference, DBSC, layout, and tests, route
rename should happen before OIDC and i18n cleanup.

## IdP/RP Impact

The sign IdP and Acme RP must be updated together.

Update:

- `app/config/oidc/client_registry.rb`
- Acme callback controllers
- Acme SSO initiators
- sign logout handling tests
- RP browser-flow tests
- identity provisioning tests
- model-layer tests that assert `audience`

No long-lived compatibility alias is required for `acme_app`, `acme_com`, or `acme_org` because the
OIDC configuration is internal and there is no staging or production deployment to preserve.

## Implementation Order

1. Rename route fragment, route scope, controller paths, controller constants, view paths, layouts,
   and assets.
2. Remove Core controller inheritance from the RP boundary. Core should use its own
   `ActionController::Base`-backed bases instead of `Acme::*`.
3. Rename route helper references across app, sign, preference, DBSC, layouts, and tests.
4. Rename OIDC client ids, audiences, callback ids, and sign/RP links.
5. Rename `ACME_*` environment/config names to `ACME_*`.
6. Rename i18n keys and exposed labels.
7. Rename test files/classes and update route, OIDC, i18n, and security assertions.
8. Update current docs and remove stale current-plan references to `acme` as an RP boundary.

## Test Plan

Run narrow tests first:

```bash
bin/rails test test/controllers/acme
bin/rails test test/integration/acme_roots_test.rb test/integration/acme_cross_domain_test.rb
bin/rails test test/services/oidc/client_registry_test.rb test/services/oidc/logout_request_test.rb
bin/rails test test/integration/oidc_rp_browser_flow_test.rb
bin/rails test test/initializers/locale_test.rb
```

Then run boundary/security coverage:

```bash
bin/rails test test/controllers/controller_base_inheritance_test.rb
bin/rails test test/controllers/controller_surface_structure_test.rb
bin/rails test test/controllers/edge/healths_controller_test.rb
bin/rails test test/controllers/public_robots_routing_test.rb
bin/rails test test/unit/security/action_policy_usage_test.rb
bin/rails test test/unit/security/authentication_mode_inventory_test.rb
bin/rails test test/security/invariants/csrf_security_invariant_test.rb
```

Run broader tests if route, OIDC, or i18n changes reveal cross-surface fallout:

```bash
bin/rails test
```

## Risks

- Accidentally renaming DNS apex-domain terminology.
- Missing a route helper reference in sign, preference, DBSC, or layouts.
- Missing an OIDC `client_id` or `aud` expectation.
- Breaking signed logout request verification during the rename.
- Breaking host configuration by renaming `ACME_*` to `ACME_*` without updating CI and Docker env.
- Replacing old Core-to-Acme inheritance with Core-to-Acme inheritance instead of removing the RP
  boundary dependency.
- Leaving i18n views pointed at removed `acme.*` keys.
- Confusing archived historical plans with current implementation guidance.
