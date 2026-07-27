# frozen_string_literal: true

# Fail-closed preconditions for removing the legacy per-surface publishing
# tables after content authority has moved to the central publishing database.
# This module is migration-only.
module PublishingLegacyTableDrop
  module_function

  class PreconditionError < StandardError; end

  APPROVAL_ENV = "PUBLISHING_LEGACY_TABLE_DROP_APPROVAL"
  APPROVAL_VALUE = "drop-empty-legacy-publishing-tables:production:app,com,org"
  SURFACES = %i(app com org).freeze
  LEAN_TABLES = %w(docs_content_entries news_content_entries help_content_entries).freeze
  CMS_FAMILIES = %w(docs news info help).freeze
  # No drop order alone can satisfy these tables: post_versions and
  # post_revisions reference each other (fk_<surface>_<family>_restore_version_post
  # and fk_<surface>_<family>_version_revision_post), so the dependency graph has
  # a cycle. The foreign keys are removed before any drop instead; see #call.
  CMS_TABLE_SUFFIXES = %w(
    post_version_tags post_version_categories post_revision_tags post_revision_categories
    tags categories media_usages media_files post_publications post_versions
    post_revisions post_slugs posts
  ).freeze

  def call(migration, surface:)
    surface = surface.to_sym
    raise ArgumentError, "unsupported publishing legacy surface: #{surface.inspect}" unless SURFACES.include?(surface)

    verify_production_approval!
    tables = tables_for(surface: surface)
    verify_tables_exist!(migration.connection, tables)
    verify_tables_empty!(migration.connection, tables)

    migration.safety_assured do
      remove_foreign_keys_between!(migration, tables)
      tables.each { |table| migration.drop_table(table) }
    end
  end

  # Detaches the legacy tables from each other before dropping any of them.
  # Every table here is being removed, so its foreign keys are removed too; only
  # constraints pointing inside the drop set are touched, and a foreign key from
  # a surviving table would still raise on drop rather than be silently deleted.
  def remove_foreign_keys_between!(migration, tables)
    drop_set = tables.to_set

    tables.each do |table|
      migration.connection.foreign_keys(table).each do |foreign_key|
        next unless drop_set.include?(foreign_key.to_table)

        migration.remove_foreign_key(table, name: foreign_key.name)
      end
    end
  end
  private_class_method :remove_foreign_keys_between!

  def tables_for(surface:)
    surface = surface.to_sym
    raise ArgumentError, "unsupported publishing legacy surface: #{surface.inspect}" unless SURFACES.include?(surface)

    LEAN_TABLES + CMS_FAMILIES.flat_map { |family|
      CMS_TABLE_SUFFIXES.map { |suffix| "#{surface}_#{family}_#{suffix}" }
    }
  end

  def verify_production_approval!
    return unless Rails.env.production?

    approval = ENV.fetch(APPROVAL_ENV)
    return if approval == APPROVAL_VALUE

    raise PreconditionError, "#{APPROVAL_ENV} does not contain the exact approved production value"
  rescue KeyError
    raise PreconditionError, "#{APPROVAL_ENV} is required for the production legacy publishing table drop"
  end
  private_class_method :verify_production_approval!

  def verify_tables_exist!(connection, tables)
    missing = tables.reject { |table| connection.table_exists?(table) }
    return if missing.empty?

    raise PreconditionError, "missing expected legacy publishing tables: #{missing.join(", ")}"
  end
  private_class_method :verify_tables_exist!

  def verify_tables_empty!(connection, tables)
    nonempty =
      tables.filter_map { |table|
        quoted_table = connection.quote_table_name(table)
        count = connection.select_value("SELECT COUNT(*) FROM #{quoted_table}").to_i
        "#{table}=#{count}" if count.positive?
      }
    return if nonempty.empty?

    raise PreconditionError, "legacy publishing tables are not empty: #{nonempty.join(", ")}"
  end
  private_class_method :verify_tables_empty!
end
