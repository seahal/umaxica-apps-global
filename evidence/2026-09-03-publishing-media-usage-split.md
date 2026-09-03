# Publishing media usage split (Phase 1B)

- Date: 2026-09-03
- Scope: Split `publishing_media_usages` into owner-explicit tables; promotion/restore
  copy; architecture guards; CMS controller concern contract. No Edge code.
- Worktree: umaxica-apps-jit-global at `80dc4151fce6d290c8a5ead581126adc975b62c7`
  plus uncommitted Phase 1 and Phase 1B changes.

## Migration design

1. `20260903180000_create_publishing_owner_media_usages` — Rails DSL
   `create_table` / `add_index` / `add_check_constraint` / `add_foreign_key`.
2. `20260903180100_split_publishing_media_usages` — `INSERT...SELECT` copy by
   owner, `drop_table` of the exclusive-arc table, attach existing promoted-
   revision and immutability trigger functions, add a deferred media
   completeness trigger.

Data copy in this environment: both development and test copies selected zero
rows (the old table was empty). The copy SQL is identity-preserving on
`public_id` and owner FK.

## Raw SQL exceptions

- `INSERT...SELECT` for bounded data copy without loading application models.
- `CREATE TRIGGER` / `CREATE FUNCTION` / `CREATE CONSTRAINT TRIGGER` because
  Rails DSL cannot express PostgreSQL immutability, promoted-revision guards,
  or deferred completeness.

## Commands

```text
bin/rails db:migrate:publishing
RAILS_ENV=test bin/rails db:migrate:publishing

bin/rails test test/models/publishing/ test/operations/publishing/ \
  test/controllers/publishing_content_matrix_test.rb \
  test/controllers/concerns/publishing_content_rendering_contract_test.rb \
  test/controllers/concerns/registration_and_content_seams_test.rb \
  test/contracts/publishing_entry_api_contract_test.rb \
  test/queries/publishing_published_entries_query_test.rb \
  test/tooling/database_reconstruction_authority_test.rb
# 140 runs, 577 assertions, 0 failures

bin/rails test test/controllers/info_surface_publishing_test.rb \
  test/controllers/help_docs_news_surface_smoke_test.rb \
  test/controllers/publishing_content_matrix_test.rb \
  test/controllers/concerns/publishing_content_rendering_contract_test.rb
# 9 runs, 287 assertions, 0 failures

bin/rubocop (Phase 1B Ruby files)
# 12 files, no offenses
```

## Concern scan

Publishing-related `included do` remains on `PublicId`,
`PublishingTaxonomyAssignment`, `PublishingTaxonomySnapshot`, and
`ApiContentNegotiation`. `PublishingContentRendering` has none. None were
removed; each retained occurrence is documented in source.

## Remaining issues

- `publishing_entry_revisions.restored_from_revision_id` XOR
  `restored_from_version_id` is optional restore provenance, not row ownership;
  left unchanged.
- Region uniqueness vs CHECK still unresolved.
- Edge CMS consumption still not implemented.
- Stub `db/*_structure.sql` dumps still not regenerated.
