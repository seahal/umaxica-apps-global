# frozen_string_literal: true

# Builds the database schema shared by every CMS family. This module is migration-only.
# rubocop:disable Naming/MethodParameterName -- concise migration DSL aliases keep the shared DDL readable.
module CmsSchema
  module_function

  PUBLIC_ID = "char_length(public_id) = 21".freeze
  SLUG = "slug ~ '^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$'".freeze
  DIGEST = "content_digest ~ '^[0-9a-f]{64}$'".freeze

  def create_family(migration, surface:, family:)
    prefix = "#{surface}_#{family}"
    migration.enable_extension("btree_gist") unless migration.extension_enabled?("btree_gist")

    create_posts(migration, prefix)
    create_slugs(migration, prefix)
    create_revisions(migration, prefix)
    add_current_revision(migration, prefix)
    create_versions(migration, prefix)
    create_publications(migration, prefix)
    create_media(migration, prefix)
    create_taxonomy(migration, prefix)
    create_assignments(migration, prefix)
  end

  def create_posts(m, p)
    m.create_table("#{p}_posts") do |t|
      public_id(t)
      t.string(:locale, null: false)
      archive(t)
      t.integer(:lock_version, null: false, default: 0)
      t.timestamps(null: false)
    end
    finish_public_id(m, "#{p}_posts")
    m.add_check_constraint("#{p}_posts", "lock_version >= 0", name: "chk_#{p}_posts_lock_version")
    archive_check(m, "#{p}_posts")
    m.add_index("#{p}_posts", %i(id locale), unique: true)
  end

  def create_slugs(m, p)
    table = "#{p}_post_slugs"
    m.create_table(table) do |t|
      public_id(t)
      t.references(:post, null: false, foreign_key: { to_table: "#{p}_posts", on_delete: :restrict })
      t.string(:locale, null: false)
      t.string(:slug, null: false)
      t.string(:state, null: false)
      t.datetime(:canonicalized_at)
      t.datetime(:redirected_at)
      t.timestamps(null: false)
    end
    finish_public_id(m, table)
    m.add_index(table, %i(locale slug), unique: true)
    m.add_index(table, :post_id, unique: true, where: "state = 'reserved'", name: "uidx_#{p}_reserved_slug")
    m.add_index(table, :post_id, unique: true, where: "state = 'canonical'", name: "uidx_#{p}_canonical_slug")
    m.add_check_constraint(table, "state IN ('reserved','canonical','redirect')", name: "chk_#{p}_slug_state")
    m.add_check_constraint(table, SLUG, name: "chk_#{p}_slug_format")
    m.add_check_constraint(table, "(state = 'reserved' AND canonicalized_at IS NULL AND redirected_at IS NULL) OR (state = 'canonical' AND canonicalized_at IS NOT NULL AND redirected_at IS NULL) OR (state = 'redirect' AND canonicalized_at IS NOT NULL AND redirected_at IS NOT NULL AND redirected_at >= canonicalized_at)", name: "chk_#{p}_slug_timestamps")
    composite_fk(m, table, %i(post_id locale), "#{p}_posts", %i(id locale), "fk_#{p}_slug_post_locale")
  end

  def create_revisions(m, p)
    table = "#{p}_post_revisions"
    m.create_table(table) do |t|
      public_id(t)
      t.references(:post, null: false, foreign_key: { to_table: "#{p}_posts", on_delete: :restrict })
      t.bigint(:restored_from_revision_id)
      t.bigint(:restored_from_version_id)
      content(t)
      provenance(t)
      t.integer(:sequence, null: false)
      t.timestamps(null: false)
    end
    finish_public_id(m, table)
    m.add_index(table, %i(post_id sequence), unique: true)
    m.add_index(table, %i(id post_id), unique: true)
    m.add_index(table, %i(id locale), unique: true)
    m.add_index(table, %i(id post_id locale), unique: true)
    content_checks(m, table, p)
    m.add_check_constraint(table, "sequence > 0", name: "chk_#{p}_revision_sequence")
    m.add_check_constraint(table, "num_nonnulls(restored_from_revision_id, restored_from_version_id) <= 1", name: "chk_#{p}_restore_source")
    m.add_foreign_key(table, table, column: %i(restored_from_revision_id post_id), primary_key: %i(id post_id), on_delete: :restrict, name: "fk_#{p}_restore_revision_post")
    composite_fk(m, table, %i(post_id locale), "#{p}_posts", %i(id locale), "fk_#{p}_revision_post_locale")
  end

  def add_current_revision(m, p)
    posts = "#{p}_posts"
    revisions = "#{p}_post_revisions"
    m.add_column(posts, :current_revision_id, :bigint)
    m.add_index(posts, :current_revision_id, unique: true)
    m.add_foreign_key(posts, revisions, column: %i(current_revision_id id), primary_key: %i(id post_id), on_delete: :restrict, name: "fk_#{p}_current_revision_post")
  end

  def create_versions(m, p)
    table = "#{p}_post_versions"
    m.create_table(table) do |t|
      public_id(t)
      t.references(:post, null: false, foreign_key: { to_table: "#{p}_posts", on_delete: :restrict })
      t.references(:post_revision, null: false, index: false)
      content(t)
      provenance(t)
      t.integer(:sequence, null: false)
      t.timestamps(null: false)
    end
    finish_public_id(m, table)
    m.add_index(table, %i(post_id sequence), unique: true)
    m.add_index(table, :post_revision_id, unique: true)
    m.add_index(table, %i(id post_id), unique: true)
    m.add_index(table, %i(id locale), unique: true)
    m.add_index(table, %i(id post_id locale), unique: true)
    m.add_foreign_key(table, "#{p}_post_revisions", column: %i(post_revision_id post_id), primary_key: %i(id post_id), on_delete: :restrict, name: "fk_#{p}_version_revision_post")
    composite_fk(m, table, %i(post_id locale), "#{p}_posts", %i(id locale), "fk_#{p}_version_post_locale")
    content_checks(m, table, p)
    m.add_check_constraint(table, "sequence > 0", name: "chk_#{p}_version_sequence")
    m.add_foreign_key("#{p}_post_revisions", table, column: %i(restored_from_version_id post_id), primary_key: %i(id post_id), on_delete: :restrict, name: "fk_#{p}_restore_version_post")
  end

  def create_publications(m, p)
    table = "#{p}_post_publications"
    m.create_table(table) do |t|
      public_id(t)
      t.references(:post, null: false, foreign_key: { to_table: "#{p}_posts", on_delete: :restrict })
      t.references(:post_version, null: false)
      t.datetime(:effective_from, null: false)
      t.datetime(:effective_until)
      t.datetime(:cancelled_at)
      t.string(:cancellation_reason)
      t.datetime(:terminated_at)
      t.string(:termination_reason)
      provenance(t)
      t.timestamps(null: false)
    end
    finish_public_id(m, table)
    m.add_foreign_key(table, "#{p}_post_versions", column: %i(post_version_id post_id), primary_key: %i(id post_id), on_delete: :restrict, name: "fk_#{p}_publication_version_post")
    m.add_check_constraint(table, "effective_until IS NULL OR effective_until > effective_from", name: "chk_#{p}_publication_window")
    m.add_check_constraint(table, "NOT (cancelled_at IS NOT NULL AND terminated_at IS NOT NULL)", name: "chk_#{p}_publication_end_mode")
    m.add_check_constraint(table, "(cancelled_at IS NULL AND cancellation_reason IS NULL) OR (cancelled_at IS NOT NULL AND cancellation_reason IS NOT NULL AND cancelled_at < effective_from)", name: "chk_#{p}_publication_cancellation")
    m.add_check_constraint(table, "(terminated_at IS NULL AND termination_reason IS NULL) OR (terminated_at IS NOT NULL AND termination_reason IS NOT NULL AND terminated_at >= effective_from AND effective_until = terminated_at)", name: "chk_#{p}_publication_termination")
    m.add_exclusion_constraint(
      table,
      "post_id WITH =, tstzrange(effective_from, effective_until, '[)') WITH &&",
      using: :gist, where: "cancelled_at IS NULL",
      name: "excl_#{p}_publication_windows",
    )
  end

  def create_media(m, p)
    files = "#{p}_media_files"
    m.create_table(files) do |t|
      public_id(t)
      t.string(:storage_key, null: false)
      t.string(:content_type, null: false)
      t.bigint(:byte_size, null: false)
      t.string(:digest_algorithm, null: false)
      t.string(:digest, null: false)
      t.integer(:width)
      t.integer(:height)
      t.jsonb(:metadata, null: false, default: {})
      archive(t)
      t.datetime(:purged_at)
      t.timestamps(null: false)
    end
    finish_public_id(m, files)
    m.add_index(files, :storage_key, unique: true)
    m.add_check_constraint(files, "byte_size >= 0", name: "chk_#{p}_media_size")
    m.add_check_constraint(files, "digest_algorithm = 'sha256' AND digest ~ '^[0-9a-f]{64}$'", name: "chk_#{p}_media_digest")
    m.add_check_constraint(files, "(width IS NULL AND height IS NULL) OR (width > 0 AND height > 0)", name: "chk_#{p}_media_dimensions")
    m.add_check_constraint(files, "jsonb_typeof(metadata) = 'object'", name: "chk_#{p}_media_metadata")
    archive_check(m, files)

    usages = "#{p}_media_usages"
    m.create_table(usages) do |t|
      public_id(t)
      t.references(:media_file, null: false, foreign_key: { to_table: files, on_delete: :restrict })
      t.references(:post, null: false, foreign_key: { to_table: "#{p}_posts", on_delete: :restrict })
      t.bigint(:post_revision_id)
      t.bigint(:post_version_id)
      t.string(:locale, null: false)
      t.string(:role, null: false)
      t.string(:field_path)
      t.string(:block_path)
      t.integer(:position, null: false, default: 0)
      t.string(:alt_text)
      t.text(:caption)
      t.jsonb(:presentation_metadata)
      t.timestamps(null: false)
    end
    finish_public_id(m, usages)
    m.add_check_constraint(usages, "num_nonnulls(post_revision_id, post_version_id) = 1", name: "chk_#{p}_media_owner_xor")
    m.add_check_constraint(usages, "position >= 0", name: "chk_#{p}_media_position")
    m.add_check_constraint(usages, "field_path IS NOT NULL OR block_path IS NOT NULL", name: "chk_#{p}_media_path")
    m.add_check_constraint(usages, "presentation_metadata IS NULL OR jsonb_typeof(presentation_metadata) = 'object'", name: "chk_#{p}_presentation_metadata")
    m.add_index(usages, %i(post_revision_id role field_path block_path position), unique: true, where: "post_revision_id IS NOT NULL", name: "uidx_#{p}_revision_media_position")
    m.add_index(usages, %i(post_version_id role field_path block_path position), unique: true, where: "post_version_id IS NOT NULL", name: "uidx_#{p}_version_media_position")
    m.add_foreign_key(usages, "#{p}_post_revisions", column: %i(post_revision_id post_id), primary_key: %i(id post_id), on_delete: :restrict, name: "fk_#{p}_media_revision_post")
    m.add_foreign_key(usages, "#{p}_post_versions", column: %i(post_version_id post_id), primary_key: %i(id post_id), on_delete: :restrict, name: "fk_#{p}_media_version_post")
  end

  def create_taxonomy(m, p)
    categories = "#{p}_categories"
    m.create_table(categories) do |t|
      public_id(t)
      t.bigint(:parent_id)
      t.string(:locale, null: false)
      t.string(:slug, null: false)
      t.string(:name, null: false)
      t.string(:normalized_name, null: false)
      t.integer(:position, null: false, default: 0)
      t.integer(:depth, null: false, default: 0)
      archive(t)
      t.timestamps(null: false)
    end
    taxonomy_indexes(m, categories, p)
    m.add_foreign_key(categories, categories, column: %i(parent_id locale), primary_key: %i(id locale), on_delete: :restrict, name: "fk_#{p}_category_parent_locale")
    m.add_check_constraint(categories, "parent_id IS NULL OR parent_id <> id", name: "chk_#{p}_category_not_self")
    m.add_check_constraint(categories, "position >= 0 AND depth BETWEEN 0 AND 8", name: "chk_#{p}_category_position_depth")

    tags = "#{p}_tags"
    m.create_table(tags) do |t|
      public_id(t)
      t.string(:locale, null: false)
      t.string(:slug, null: false)
      t.string(:name, null: false)
      t.string(:normalized_name, null: false)
      archive(t)
      t.timestamps(null: false)
    end
    taxonomy_indexes(m, tags, p)
  end

  def create_assignments(m, p)
    { post_revision: "post_revisions", post_version: "post_versions" }.each do |owner, owner_suffix|
      category = "#{p}_#{owner}_categories"
      m.create_table(category) do |t|
        public_id(t)
        t.references(owner, null: false, foreign_key: { to_table: "#{p}_#{owner_suffix}", on_delete: :restrict })
        t.references(:category, null: false, foreign_key: { to_table: "#{p}_categories", on_delete: :restrict })
        snapshot(t)
        t.timestamps(null: false)
      end
      finish_public_id(m, category)
      m.add_index(category, "#{owner}_id", unique: true, name: "uidx_#{p}_#{owner}_category_owner")
      assignment_checks(m, category, p)
      m.add_foreign_key(category, "#{p}_#{owner_suffix}", column: ["#{owner}_id", :locale], primary_key: %i(id locale), on_delete: :restrict, name: "fk_#{p}_#{owner}_category_locale")
      m.add_foreign_key(category, "#{p}_categories", column: %i(category_id locale), primary_key: %i(id locale), on_delete: :restrict, name: "fk_#{p}_#{owner}_category_term_locale")

      tag = "#{p}_#{owner}_tags"
      m.create_table(tag) do |t|
        public_id(t)
        t.references(owner, null: false, foreign_key: { to_table: "#{p}_#{owner_suffix}", on_delete: :restrict })
        t.references(:tag, null: false, foreign_key: { to_table: "#{p}_tags", on_delete: :restrict })
        snapshot(t)
        t.integer(:position, null: false)
        t.timestamps(null: false)
      end
      finish_public_id(m, tag)
      m.add_index(tag, ["#{owner}_id", :tag_id], unique: true, name: "uidx_#{p}_#{owner}_tag_term")
      m.add_index(tag, ["#{owner}_id", :position], unique: true, name: "uidx_#{p}_#{owner}_tag_position")
      assignment_checks(m, tag, p)
      m.add_check_constraint(tag, "position >= 0", name: "chk_#{p}_#{owner}_tag_position")
      m.add_foreign_key(tag, "#{p}_#{owner_suffix}", column: ["#{owner}_id", :locale], primary_key: %i(id locale), on_delete: :restrict, name: "fk_#{p}_#{owner}_tag_locale")
      m.add_foreign_key(tag, "#{p}_tags", column: %i(tag_id locale), primary_key: %i(id locale), on_delete: :restrict, name: "fk_#{p}_#{owner}_tag_term_locale")
    end
  end

  def public_id(t) = t.string(:public_id, limit: 21, null: false)

  def provenance(t) = t.string(:created_by_operator_public_id, limit: 21)

  def archive(t)
    t.datetime(:archived_at)
    t.string(:archive_reason)
  end

  def content(t)
    t.string(:locale, null: false)
    t.string(:title, null: false)
    t.text(:summary)
    t.jsonb(:body, null: false)
    t.integer(:schema_version, null: false)
    t.string(:content_digest, limit: 64, null: false)
  end

  def snapshot(t)
    t.string(:locale, null: false)
    t.string(:taxonomy_public_id_snapshot, limit: 21, null: false)
    t.string(:slug_snapshot, null: false)
    t.string(:name_snapshot, null: false)
    t.jsonb(:path_snapshot, null: false, default: [])
  end

  def finish_public_id(m, table)
    m.add_index(table, :public_id, unique: true)
    m.add_check_constraint(table, PUBLIC_ID, name: "chk_#{table}_public_id")
  end

  def archive_check(m, table)
    m.add_check_constraint(table, "(archived_at IS NULL AND archive_reason IS NULL) OR (archived_at IS NOT NULL AND archive_reason IS NOT NULL)", name: "chk_#{table}_archive")
  end

  def content_checks(m, table, _p)
    m.add_check_constraint(table, "jsonb_typeof(body) = 'object'", name: "chk_#{table}_body")
    m.add_check_constraint(table, "schema_version > 0", name: "chk_#{table}_schema")
    m.add_check_constraint(table, DIGEST, name: "chk_#{table}_digest")
  end

  def taxonomy_indexes(m, table, _p)
    finish_public_id(m, table)
    m.add_index(table, %i(locale slug), unique: true)
    m.add_index(table, %i(locale normalized_name), unique: true)
    m.add_index(table, %i(id locale), unique: true)
    m.add_check_constraint(table, SLUG, name: "chk_#{table}_slug")
    archive_check(m, table)
  end

  def assignment_checks(m, table, _p)
    m.add_check_constraint(table, "jsonb_typeof(path_snapshot) = 'array'", name: "chk_#{table}_path")
  end

  def composite_fk(m, from, columns, to, primary_key, name)
    m.add_foreign_key(from, to, column: columns, primary_key:, on_delete: :restrict, name:)
  end
end
# rubocop:enable Naming/MethodParameterName
