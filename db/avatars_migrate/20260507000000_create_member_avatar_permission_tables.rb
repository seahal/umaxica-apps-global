# frozen_string_literal: true

class CreateMemberAvatarPermissionTables < ActiveRecord::Migration[8.2]
  TABLES = %i[
    member_avatar_accesses
    member_avatar_visibilities
    member_avatar_oversights
    member_avatar_extractions
    member_avatar_impersonations
    member_avatar_suspensions
    member_avatar_deletions
  ].freeze

  def change
    TABLES.each do |table_name|
      create_table(table_name) do |t|
        t.bigint(:member_id, null: false)
        t.bigint(:avatar_id, null: false)
        t.timestamps

        t.index(%i[member_id avatar_id], unique: true)
        t.index(:avatar_id)
      end

      add_foreign_key(table_name, :avatars, column: :avatar_id, validate: false)
    end
  end
end
