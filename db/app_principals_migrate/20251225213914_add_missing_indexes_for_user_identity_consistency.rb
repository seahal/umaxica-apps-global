# frozen_string_literal: true

class AddMissingIndexesForUserIdentityConsistency < ActiveRecord::Migration[7.1]
  def up
    add_index(:accounts, %i(accountable_type accountable_id), unique: true, if_not_exists: true)
    add_index(:user_identity_audits, :subject_id, if_not_exists: true)
  end

  def down
  end
end
