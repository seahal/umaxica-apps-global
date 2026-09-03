# Publishing Persistence And Controller Design

Current architecture for the global publishing/CMS boundary. Historical ADRs remain
in `adr/`; this document records the rules in force after the media-usage split.

## Persistence is global

The 3 × 4 content matrix (`app`/`com`/`org` × `info`/`docs`/`news`/`help`) shares
one `publishing` database. There are not twelve CMS databases and not separate
regional publishing databases. Edge hostname or region naming does not change
persistence ownership.

## Persistence polymorphism is prohibited

Publishing relations must have one ownership meaning. Do not represent
heterogeneous owners through:

- Rails `polymorphic: true` associations
- `*_type` + `*_id` columns
- STI (`type` inheritance columns)
- exclusive-arc / union-owner tables (nullable alternative foreign keys)
- discriminator values that change the foreign-key graph or lifecycle
- EAV used to emulate different entity types
- dynamic model or table selection (`constantize`, `safe_constantize`)

Ordinary classification is allowed. Taxonomy `kind` classifies a vocabulary that
is still one entity with one ownership and lifecycle.

Ruby polymorphism (modules, composition, ordinary method dispatch) is allowed.

## Media ownership

Draft placements live in `publishing_revision_media_usages` and belong to an
entry revision. Released placements live in `publishing_version_media_usages`
and belong to an entry version. Both point at `publishing_media_files`. The
former exclusive-arc table `publishing_media_usages` is gone.

Promotion copies revision media onto the version. Restore copies version media
onto a new revision. Version media is immutable. Promoted revision media cannot
change.

## Migration DSL

Prefer Rails migration DSL (`create_table`, `add_foreign_key`, `add_index`,
`add_check_constraint`, `drop_table`). Raw SQL, triggers, and exclusion
constraints are exceptions: they must be justified, narrowly scoped, tested, and
must not drop an integrity constraint for portability theatre.

## Rails controllers

The twelve public entry controllers stay explicit and thin. Shared list/detail
rendering lives in `PublishingContentRendering`. Each controller declares
`PUBLISHING_AUDIENCE` and `PUBLISHING_SURFACE`. Including that concern must not
infer those values from the class name.

`included do` is an exception. Keep it only when it is the clearest statement of
a persistence or request-filter contract, and document why.

## Related

- `adr/publishing-persistence-polymorphism-prohibition.md`
- `adr/publishing-db-content-authority.md`
- `docs/architecture/content-surface-matrix.md`
