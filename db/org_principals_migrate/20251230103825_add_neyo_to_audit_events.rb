# frozen_string_literal: true

class AddNeyoToAuditEvents < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      # Add NEYO event to user_identity_audit_events

      # Add NEYO event to staff_identity_audit_events
    end
  end

  def down
    # No-op to avoid removing reference data used by existing records
  end
end
