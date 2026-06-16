# frozen_string_literal: true

class AddOnDeleteActionsToAvatarRelationshipForeignKeys < ActiveRecord::Migration[8.2]
  def up
    remove_foreign_key(:avatar_blocks, column: :blocked_avatar_id) if foreign_key_exists?(:avatar_blocks, column: :blocked_avatar_id)
    remove_foreign_key(:avatar_blocks, column: :blocker_avatar_id) if foreign_key_exists?(:avatar_blocks, column: :blocker_avatar_id)
    remove_foreign_key(:avatar_mutes, column: :muted_avatar_id) if foreign_key_exists?(:avatar_mutes, column: :muted_avatar_id)
    remove_foreign_key(:avatar_mutes, column: :muter_avatar_id) if foreign_key_exists?(:avatar_mutes, column: :muter_avatar_id)

    add_foreign_key :avatar_blocks, :avatars, column: :blocked_avatar_id, on_delete: :cascade, validate: false
    add_foreign_key :avatar_blocks, :avatars, column: :blocker_avatar_id, on_delete: :cascade, validate: false
    add_foreign_key :avatar_mutes, :avatars, column: :muted_avatar_id, on_delete: :cascade, validate: false
    add_foreign_key :avatar_mutes, :avatars, column: :muter_avatar_id, on_delete: :cascade, validate: false
  end

  def down
    remove_foreign_key(:avatar_blocks, column: :blocked_avatar_id) if foreign_key_exists?(:avatar_blocks, column: :blocked_avatar_id)
    remove_foreign_key(:avatar_blocks, column: :blocker_avatar_id) if foreign_key_exists?(:avatar_blocks, column: :blocker_avatar_id)
    remove_foreign_key(:avatar_mutes, column: :muted_avatar_id) if foreign_key_exists?(:avatar_mutes, column: :muted_avatar_id)
    remove_foreign_key(:avatar_mutes, column: :muter_avatar_id) if foreign_key_exists?(:avatar_mutes, column: :muter_avatar_id)

    add_foreign_key :avatar_blocks, :avatars, column: :blocked_avatar_id, validate: false
    add_foreign_key :avatar_blocks, :avatars, column: :blocker_avatar_id, validate: false
    add_foreign_key :avatar_mutes, :avatars, column: :muted_avatar_id, validate: false
    add_foreign_key :avatar_mutes, :avatars, column: :muter_avatar_id, validate: false
  end
end
