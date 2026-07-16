# frozen_string_literal: true

# Drops the lean content-entry tables and the 2026-07-11 CMS family tables now
# that content authority has moved to the central publishing DB. See
# adr/publishing-db-content-authority.md and
# plans/publishing-db-valiant-moore.md Phase 7. Both source migrations
# (20260613000001, 20260711010002) are kept in history and left unedited.
class DropPublishingMigrationSourceTables < ActiveRecord::Migration[8.0]
  LEAN_TABLES = %i(docs_content_entries news_content_entries help_content_entries).freeze
  CMS_FAMILIES = %i(docs news info help).freeze
  CMS_TABLE_SUFFIXES = %w(
    post_version_tags post_version_categories post_revision_tags post_revision_categories
    tags categories media_usages media_files post_publications post_versions
    post_revisions post_slugs posts
  ).freeze

  def up
    safety_assured do
      LEAN_TABLES.each { |table| drop_table(table, if_exists: true, force: :cascade) }
      CMS_FAMILIES.each do |family|
        CMS_TABLE_SUFFIXES.each { |suffix| drop_table("org_#{family}_#{suffix}", if_exists: true, force: :cascade) }
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
