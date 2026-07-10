# GH-582: Remove Dead Code and Deprecated Methods Flagged for Deletion

GitHub: #582

## Summary

~20 annotations across controllers and models mark code for deletion that has not yet been cleaned
up.

## Affected Files

### Controllers

- `app/controllers/acme/app/application_controller.rb:9,14` — `delete this!`
- `app/controllers/acme/com/application_controller.rb:13,14,15` — `delete this!`
- `app/controllers/acme/org/application_controller.rb:23-31` — `delete this line` (9 lines)
- `app/controllers/sign/org/application_controller.rb:12-14` — `i want to remove this` (3 lines)

### Models

- `app/models/com_preference_colortheme_option.rb:34` — `DELETE THIS METHOD!`
- `app/models/user_token.rb:97` — `remove this method!`
- `app/models/user_token_binding_method.rb:19` — `remove this method!`
- `app/models/user_token_dbsc_status.rb:21` — `remove this method!`

## Action

Review each flagged location, confirm the code is safe to remove, delete it, and remove the
annotations. Add test coverage where needed to verify no regressions.

## Implementation Status (2026-04-07)

**Status: COMPLETE**

All 8 annotations have been removed from the codebase. Files still exist but no longer contain the
flagged deletion markers. This issue can be closed.

## Improvement Points (2026-04-07 Review)

- Run a fresh dead-code audit first. Comment-based deletion markers age quickly, and this plan
  should not assume every annotated method is still unused.
- Group removals by domain or subsystem so review can validate behavior with targeted tests instead
  of one large deletion batch.
