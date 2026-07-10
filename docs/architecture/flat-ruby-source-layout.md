# Flat Ruby Source Layout

Ruby application code under selected support roots uses a flat file layout. Former directory
segments are encoded in the file name and the Zeitwerk constant name.

Target roots:

- `app/services`
- `app/models/concerns`
- `app/controllers/concerns`
- application Ruby under `lib`

Excluded roots:

- concrete models under `app/models` outside `app/models/concerns`
- concrete controllers under `app/controllers` outside `app/controllers/concerns`
- `app/views`
- routes, database migrations, schema files, and fixtures
- `lib/tasks`, `lib/assets`, `lib/templates`, `lib/generators`, and configured `lib` ignore-only
  support directories

Naming rules:

- Move target Ruby files directly under their root.
- Encode former path segments as a flat snake_case file name.
- The file name must match the flat CamelCase Zeitwerk constant.
- Concern files live under a concerns root, so they do not repeat `concern` in the file name or
  constant name.
- Do not use leading underscore file names for private Ruby code. Use API boundaries, tests, and
  references to control visibility.
- Do not append `Service` blindly. Use role suffixes when they describe the object: `Service`,
  `Authority`, `Guard`, `Verifier`, `Encoder`, `Decoder`, `Client`, and `Adapter`.

The rule is intentionally simple: a flat support root is already a classifier. Repeating the
classifier in every file name creates noise and makes constant names longer without adding useful
domain information. Directory history is preserved in the prefix (`sign_email_registration_flow`),
while the root supplies the category (`app/controllers/concerns`). This keeps Zeitwerk predictable
and makes references easier to scan after the former namespace directories have been removed.

Examples:

- `app/services/sign/risk/enforcer.rb` becomes `app/services/sign_risk_enforcer.rb` and defines
  `SignRiskEnforcer`.
- `app/controllers/concerns/sign/acme_authority_redirect.rb` becomes
  `app/controllers/concerns/sign_acme_authority_redirect.rb` and defines
  `SignAcmeAuthorityRedirect`.
- `lib/jit/security/jwt/jwk.rb` becomes `lib/jit_security_jwt_jwk.rb` and defines
  `JitSecurityJwtJwk`.

Concrete controllers and models are not flattened by this rule because their paths carry Rails
routing, view lookup, model table, and domain placement meaning. Flattening them requires a separate
behavior-aware migration.
