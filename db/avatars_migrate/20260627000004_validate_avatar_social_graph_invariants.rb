# frozen_string_literal: true

class ValidateAvatarSocialGraphInvariants < ActiveRecord::Migration[8.2]
  def up
    validate_check_constraint :avatar_follows, name: "chk_avatar_follows_no_self_edge"
    validate_check_constraint :avatar_blocks, name: "chk_avatar_blocks_no_self_edge"
    validate_check_constraint :avatar_mutes, name: "chk_avatar_mutes_no_self_edge"
  end

  def down
    # Validation state is not schema; the constraint definitions remain in the add migration.
  end
end
