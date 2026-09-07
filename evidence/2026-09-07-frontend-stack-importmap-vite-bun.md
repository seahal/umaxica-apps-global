# Frontend stack evidence — 2026-09-07

`config/frontend_stacks.yml` is the authoritative surface mapping. Rails application layouts emit
Propshaft + Importmap helpers and never Vite helpers. Inertia layouts emit Vite + Inertia helpers
and never Importmap. CSP nonces and server-resolved theme semantics are retained. GDPR preference
entry remains Rails-first at the server boundary.

Rendered HTML checks are encoded in `test/architecture/frontend_stack_isolation_test.rb`.
`bundle check` passed; Bun lockfile generation passed.
