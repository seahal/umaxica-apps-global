# frozen_string_literal: true

class FixUserIdentityConsistency < ActiveRecord::Migration[7.1]
  def up
    # Add missing unique indexes for user identity tables
    execute("CREATE UNIQUE INDEX IF NOT EXISTS index_user_identity_telephone_statuses_on_lower_id ON user_identity_telephone_statuses (lower(id))")
    execute("CREATE UNIQUE INDEX IF NOT EXISTS index_user_identity_emails_on_lower_address ON user_identity_emails (lower(address))")
  end

  def down
    # Irreversible or manual cleanup
  end
end
