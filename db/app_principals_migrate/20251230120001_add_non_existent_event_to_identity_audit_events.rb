# frozen_string_literal: true

class AddNonExistentEventToIdentityAuditEvents < ActiveRecord::Migration[8.2]
  def up
    return unless table_exists?(:user_identity_audit_events)

    safety_assured do
      # No-op: intentionally left blank.
    end
  end

  def down
    # No-op to avoid removing reference data used by existing records
  end
end
