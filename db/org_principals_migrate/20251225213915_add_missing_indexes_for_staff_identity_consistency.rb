# frozen_string_literal: true

class AddMissingIndexesForStaffIdentityConsistency < ActiveRecord::Migration[7.1]
  def up
    add_index(:staff_identity_audits, :subject_id, if_not_exists: true)
  end

  def down
  end
end
