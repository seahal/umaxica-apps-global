# Preference And Settings Authority

## Authority

`acme/www` owns preference writes, settings, dashboards, session-management UI, and account-local
configuration state.

`sign/id` must not own preference writes, settings pages, dashboards, account lifecycle, withdrawal,
or session-management UI. Credential enrollment screens may remain on `sign/id` only when they are
credential ceremonies delegated by acme or allowed by a current ADR.

## Physical Storage

Existing sign-side preference, settings, dashboard, or credential-management tables/models/routes do
not imply sign-side authority. Physical DB movement is out of scope for this implementation phase.

## Runtime Reads

Request-local preference reads may continue through existing runtime projection mechanisms while the
logical writer changes to acme. A read-side preference projection is not a write authority.

## Related

- `docs/architecture/preference.md`
- `docs/identity/authority-boundary.md`
