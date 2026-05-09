# frozen_string_literal: true

class ValidateMemberAvatarPermissionForeignKeys < ActiveRecord::Migration[8.2]
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
      validate_foreign_key(table_name, :avatars)
    end
  end
end
