# Preference And Settings Authority

## Authority

`acme/www` owns preference writes, account lifecycle, withdrawal, and dashboards.

`sign/id` owns the settings shell that lives on the identity host, account-local credential
configuration, and session-management UI. It must not own preference writes, account lifecycle, or
withdrawal. Credential enrollment screens may remain on `sign/id` when they are credential ceremonies
or account-local credential settings.

## Physical Storage

Existing sign-side preference, settings-shell, dashboard, or credential-management
tables/models/routes do not imply sign-side authority for persisted preference data. Physical DB
movement is out of scope for this implementation phase.

## Runtime Reads

Request-local preference reads may continue through existing runtime projection mechanisms while the
logical writer changes to acme. A read-side preference projection is not a write authority.

## Related

- `docs/architecture/preference.md`
- `docs/identity/authority-boundary.md`
