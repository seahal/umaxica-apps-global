# frozen_string_literal: true

require_relative "../migration_support/publishing_legacy_table_drop"

# Drops the lean content-entry tables and the 2026-07-11 CMS family tables now
# that content authority has moved to the central publishing DB. See
# adr/publishing-db-content-authority.md and
# plans/publishing-db-valiant-moore.md Phase 7. Both source migrations
# (20260613000001, 20260711010000) are kept in history and left unedited.
class DropPublishingMigrationSourceTables < ActiveRecord::Migration[8.0]
  def up
    PublishingLegacyTableDrop.call(self, surface: :app)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
