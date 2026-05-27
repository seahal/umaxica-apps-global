# Acme RP Boundary Naming

**Status:** Accepted (2026-05-26)

## Context

The global Rails application hosts both the IdP face and the RP face:

- `sign` is the IdP.
- The RP-facing global application boundary was historically named `apex`.
- `app`, `com`, and `org` are the domain family and database boundaries.
- `core` is internal foundation and shared infrastructure.
- `visitor`, `client`, and `operator` are persona / actor boundaries.

The word `apex` is overloaded. In DNS and URL discussions, an apex domain means the bare domain such
as `example.com`, without a subdomain. Using `Apex` as a Rails namespace, route helper prefix, OIDC
client id prefix, and RP boundary name makes DNS and application-boundary discussions easy to
misread.

This repository does not have staging or production deployments that require preserving the old
`apex` operational names. OIDC client ids and audiences are internal to this Rails application and
its paired IdP/RP configuration, so they can be renamed as part of the same implementation pass.

The database inventory found no `apex` table, column, foreign key, index, constraint, schema dump,
or database connection names. The rename is therefore an application, routing, configuration, OIDC,
i18n, test, and documentation rename, not a database schema rename.

## Decision

Rename the RP-facing global application boundary from `apex` / `Apex` to `acme` / `Acme`.

The accepted naming rules are:

- Ruby constants use `Acme`.
- paths, namespaces, route helpers, file names, and route fragment names use `acme`.
- OIDC client ids use `acme_app`, `acme_com`, and `acme_org`.
- OIDC audiences use the `acme` vocabulary, for example `umaxica-acme-app`.
- configuration and environment variables use `ACME_*`.
- i18n keys use the `acme.*` namespace.
- database table, column, foreign key, index, and constraint names would use `acme` if any are
  introduced later.
- DNS terminology remains `apex` when it specifically means an apex domain or apex-scoped cookie
  domain.

The previous structural grammar:

```text
{App,Com,Org}{Apex,Core}{Visitor,Client,Operator}
```

is replaced by:

```text
{App,Com,Org}{Acme,Core}{Visitor,Client,Operator}
```

## Consequences

- `app/controllers/apex/**`, `app/views/apex/**`, `app/views/layouts/apex/**`, and related test
  paths are renamed to `acme`.
- `Apex::*` controller constants become `Acme::*`.
- `config/routes/apex.rb` becomes `config/routes/acme.rb`, and route helper prefixes change from
  `apex_*` to `acme_*`.
- `APEX_SERVICE_URL`, `APEX_CORPORATE_URL`, `APEX_STAFF_URL`, `APEX_NETWORK_URL`, and
  `APEX_DEVELOPER_URL` become `ACME_*` equivalents.
- OIDC client registry entries and tests change from `apex_app`, `apex_com`, and `apex_org` to
  `acme_app`, `acme_com`, and `acme_org`.
- Because there is no staging or production compatibility requirement, the implementation does not
  need long-lived compatibility aliases for the old `apex` OIDC or environment names.
- Because the database inventory found no physical `apex` names, no schema migration is required for
  this rename.
- Documentation must keep DNS apex-domain usage unchanged. In particular, `apex-scoped` cookie
  domain language remains correct when it describes `.example.com` style domain scope.

## Migration Notes

Implementation should proceed in small commits:

1. Rename routes, controller namespace, view paths, layouts, and assets.
2. Remove `core` controller inheritance from the RP boundary instead of carrying it forward to
   `Acme::*`.
3. Rename OIDC client ids, audiences, callback configuration, and sign-to-RP links.
4. Rename `APEX_*` configuration to `ACME_*`.
5. Rename i18n keys and UI strings from `apex.*` / `Apex` to `acme.*` / `Acme`.
6. Rename tests and documentation.

The implementation should not rename DNS apex-domain terminology, cookie domain scope language, or
`.example.com` style test hosts.

## Related

- `adr/split-into-regional-and-global-repos.md`
- `adr/surface-database-connection-naming.md`
- `docs/security/cookie-domain-scope.md`
