# frozen_string_literal: true

require_relative "../migration_support/publishing_schema"

# Replaces the exclusive-arc publishing_media_usages table with two owner-explicit
# relations. Schema only: data copy and the drop of the old table are the next
# migration so a failed copy cannot leave the old structure gone.
class CreatePublishingOwnerMediaUsages < ActiveRecord::Migration[8.2]
  def change
    safety_assured do
      create_owner_media_usages(
        :publishing_revision_media_usages,
        owner: :entry_revision,
        owner_table: :publishing_entry_revisions,
        unique_index: "uidx_publishing_revision_media_usages_position",
        owner_fk: "fk_publishing_revision_media_revision",
      )
      create_owner_media_usages(
        :publishing_version_media_usages,
        owner: :entry_version,
        owner_table: :publishing_entry_versions,
        unique_index: "uidx_publishing_version_media_usages_position",
        owner_fk: "fk_publishing_version_media_version",
      )
    end
  end

  private

  def create_owner_media_usages(table, owner:, owner_table:, unique_index:, owner_fk:)
    owner_id = :"#{owner}_id"
    create_table(table) do |t|
      t.string(:public_id, limit: 21, null: false)
      t.references(:media_file, null: false, foreign_key: { to_table: :publishing_media_files, on_delete: :restrict })
      t.references(:entry, null: false, foreign_key: { to_table: :publishing_entries, on_delete: :restrict })
      t.bigint(owner_id, null: false)
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

    add_index(table, :public_id, unique: true)
    add_check_constraint(table, PublishingSchema::PUBLIC_ID, name: "chk_#{table}_public_id")
    add_check_constraint(table, "position >= 0", name: "chk_#{table}_position")
    add_check_constraint(
      table, "field_path IS NOT NULL OR block_path IS NOT NULL",
      name: "chk_#{table}_path",
    )
    add_check_constraint(
      table, "presentation_metadata IS NULL OR jsonb_typeof(presentation_metadata) = 'object'",
      name: "chk_#{table}_presentation_metadata",
    )
    add_index(
      table, [owner_id, :role, :field_path, :block_path, :position],
      unique: true, name: unique_index,
    )
    add_foreign_key(
      table, owner_table, column: [owner_id, :entry_id], primary_key: %i(id entry_id),
                          on_delete: :restrict, name: owner_fk,
    )
  end
end
