# Service and Runtime Improvements

1. `EventPublisher` should either be wired to the app's current notification/event mechanism or be
   removed if it is no longer part of the architecture.
2. Add unit/integration tests for `EventPublisher` to verify payload shape, headers, and error
   handling when delivery fails.
3. Guard the Active Record encryption configuration against missing credentials by using `dig` and
   sensible fallbacks to prevent boot failures.
4. Replace the global `$stderr` override in `config/application.rb` with a library-specific
   workaround to avoid hiding unrelated warnings.
5. Document the intended development workflow for any future asynchronous processing instead of
   assuming an always-on background worker.

## Notes

- `TokenService` is fully implemented in `app/services/auth/token_service.rb` (267 lines).
- `CoreService` does not exist in the codebase.

Updated: 2026-04-04
