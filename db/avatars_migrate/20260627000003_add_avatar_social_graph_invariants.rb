# frozen_string_literal: true

class AddAvatarSocialGraphInvariants < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    add_check_constraint :avatar_follows,
                         "follower_avatar_id <> followed_avatar_id",
                         name: "chk_avatar_follows_no_self_edge",
                         validate: false
    add_check_constraint :avatar_blocks,
                         "blocker_avatar_id <> blocked_avatar_id",
                         name: "chk_avatar_blocks_no_self_edge",
                         validate: false
    add_check_constraint :avatar_mutes,
                         "muter_avatar_id <> muted_avatar_id",
                         name: "chk_avatar_mutes_no_self_edge",
                         validate: false

    add_index :avatar_follows, %i[follower_avatar_id followed_avatar_id],
              unique: true,
              algorithm: :concurrently,
              name: "index_avatar_follows_on_follower_and_followed_avatar_id"
    add_index :avatar_blocks, %i[blocker_avatar_id blocked_avatar_id],
              unique: true,
              algorithm: :concurrently,
              name: "index_avatar_blocks_on_blocker_and_blocked_avatar_id"
    add_index :avatar_mutes, %i[muter_avatar_id muted_avatar_id],
              unique: true,
              algorithm: :concurrently,
              name: "index_avatar_mutes_on_muter_and_muted_avatar_id"
  end

  def down
    remove_index :avatar_mutes, name: "index_avatar_mutes_on_muter_and_muted_avatar_id"
    remove_index :avatar_blocks, name: "index_avatar_blocks_on_blocker_and_blocked_avatar_id"
    remove_index :avatar_follows, name: "index_avatar_follows_on_follower_and_followed_avatar_id"

    remove_check_constraint :avatar_mutes, name: "chk_avatar_mutes_no_self_edge"
    remove_check_constraint :avatar_blocks, name: "chk_avatar_blocks_no_self_edge"
    remove_check_constraint :avatar_follows, name: "chk_avatar_follows_no_self_edge"
  end
end
