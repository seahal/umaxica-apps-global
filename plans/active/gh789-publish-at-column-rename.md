# GH-789: Rename PostVersion `published_at` to `publish_at`

## Summary

`post_versions.published_at` is the start of the publish window paired with `expires_at`. Because it
can hold a future scheduling time, rename it to `publish_at`.

`posts.published_at` remains unchanged because it is paired with `published_by_actor_id` and reads
as the actual publication timestamp for the post aggregate.

## Implementation

- Add an avatar DB migration that renames `post_versions.published_at` to
  `post_versions.publish_at`.
- Update `PostVersion` validation and model annotations to use `publish_at`.
- Update post-version creation in tests to pass `publish_at`.
- Update `db/avatar_schema.rb` and historical avatar table creation paths so new schemas use the
  final column name.
- Update stable docs and ADR text that describe the publish window to use
  `publish_at <= now < expires_at`.

## Tests

- Cover a valid `PostVersion` with `publish_at` and `expires_at`.
- Cover missing `publish_at`.
- Cover missing `expires_at`.
- Run:
  - `bin/rails test test/models/post_test.rb`
  - `bin/rails test test/models/post_version_test.rb`

## Assumptions

- The rename applies only to `post_versions`.
- No public JSON/API field is currently exposed from `PostVersion#published_at`; if one is found
  later, update it intentionally or add compatibility handling.
