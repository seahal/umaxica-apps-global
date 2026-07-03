# frozen_string_literal: true

class CreateAvatarGroups < ActiveRecord::Migration[8.2]
  def change
    create_table :avatar_groups do |t|
      t.string :public_id, null: false
      t.string :account_surface, null: false
      t.string :account_public_id, null: false
      t.string :name, null: false
      t.text :description
      t.string :state, null: false, default: "active"
      t.datetime :archived_at

      t.timestamps
    end

    add_index :avatar_groups, :public_id, unique: true
    add_index :avatar_groups, %i[account_surface account_public_id]
    add_check_constraint :avatar_groups,
                         "account_surface IN ('app', 'org', 'com')",
                         name: "chk_avatar_groups_account_surface"
    add_check_constraint :avatar_groups,
                         "state IN ('active', 'archived')",
                         name: "chk_avatar_groups_state"
    add_check_constraint :avatar_groups,
                         "(state = 'archived') = (archived_at IS NOT NULL)",
                         name: "chk_avatar_groups_archive_state"

    create_table :group_avatar_memberships do |t|
      t.string :public_id, null: false
      t.references :avatar_group, null: false, foreign_key: { on_delete: :restrict }
      t.references :avatar, null: false, foreign_key: { on_delete: :restrict }
      t.string :role, null: false, default: "member"
      t.integer :position, null: false, default: 0
      t.string :state, null: false, default: "active"
      t.datetime :assigned_at, null: false
      t.datetime :removed_at

      t.timestamps
    end

    add_index :group_avatar_memberships, :public_id, unique: true
    add_index :group_avatar_memberships,
              %i[avatar_group_id avatar_id],
              unique: true,
              where: "removed_at IS NULL",
              name: "idx_group_avatar_memberships_active_pair"
    add_check_constraint :group_avatar_memberships,
                         "state IN ('active', 'removed')",
                         name: "chk_group_avatar_memberships_state"
    add_check_constraint :group_avatar_memberships,
                         "removed_at IS NULL OR removed_at >= assigned_at",
                         name: "chk_group_avatar_memberships_removed_after_assigned"
    add_check_constraint :group_avatar_memberships,
                         "(state = 'removed') = (removed_at IS NOT NULL)",
                         name: "chk_group_avatar_memberships_removed_state"
  end
end
