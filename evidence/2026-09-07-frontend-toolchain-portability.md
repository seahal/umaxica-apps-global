# Frontend toolchain portability evidence — 2026-09-07

The Global frontend stack has one package-manager contract: `package.json` pins Bun, the
Containerfile copies Bun from the official release image, CI installs through `oven-sh/setup-bun`,
and lefthook invokes Bun scripts. The architecture test reads those boundaries directly so a future
runtime migration cannot leave local containers, CI, or hooks on different package-manager paths.

Verification: `bundle exec ruby test/architecture/frontend_stack_isolation_test.rb` — 4 runs, 294
assertions, 0 failures, 0 errors, 0 skips.
