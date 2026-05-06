# Frontend and API Improvements

1. Move `ENV["RAILS_ENV"] ||= "test"` before the SimpleCov block so coverage reliably starts in the
   test environment.
2. Update the passkey flow to pass the server-provided WebAuthn options into
   `navigator.credentials.create` instead of using hardcoded defaults.
3. Add capability detection and fallback messaging for browsers without WebAuthn support to improve
   the passkey UX.
4. Wrap the Base64 decode in `ValidEmailAddressesController` with validation and exception handling;
   return a 400-style error when decoding fails.
5. In `ValidTelephoneNumbersController`, validate presence/format and return a 422 response with
   error reasons instead of a bare boolean.
6. Include error codes or messages in the inquiry API responses so clients can display meaningful
   feedback to users.
7. Provide development defaults or onboarding docs for the `API_*_URL` variables so the scoped
   routes are available out of the box.
8. Split the single JavaScript bundle per site segment so that each layout loads only the scripts it
   needs instead of importing every view module.
9. Stop scanning for `app/javascript/controllers` if it does not exist, or create the directory;
   this avoids unnecessary file system traversal.

## Notes

- Bun tests have been replaced with Vitest.

Updated: 2026-04-04
