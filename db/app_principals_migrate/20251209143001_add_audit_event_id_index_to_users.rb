# frozen_string_literal: true

class AddAuditEventIdIndexToUsers < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    # Users index is already handled by 20251209014633 but keeping for safety/completeness if not exists
    unless index_exists?(:users, :withdrawn_at, name: 'index_users_on_withdrawn_at')
      add_index(:users, :withdrawn_at, name: 'index_users_on_withdrawn_at', where: 'withdrawn_at IS NOT NULL')
    end

    # Indexes on audit event_id for faster joins/filters
    return if index_exists?(:user_identity_audits, :event_id, name: 'index_user_identity_audits_on_event_id')

    add_index(:user_identity_audits, :event_id, name: 'index_user_identity_audits_on_event_id')

  end
end
