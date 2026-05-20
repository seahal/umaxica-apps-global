# frozen_string_literal: true

class AddLevelToUserIdentityAudits < ActiveRecord::Migration[7.1]
  def up
    # Ensure clean slate for correct type (string required for regex check constraint)
    remove_reference(:user_identity_audits, :level) if column_exists?(:user_identity_audits, :level_id)

    add_reference(:user_identity_audits, :level, type: :string, index: true)
  end

  def down
    remove_reference(:user_identity_audits, :level) if column_exists?(:user_identity_audits, :level_id)
  end
end
