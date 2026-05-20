# frozen_string_literal: true

class AddNeyoToAuditLevels < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      # Add NEYO level to user_identity_audit_levels

      # Add NEYO level to staff_identity_audit_levels
    end
  end

  def down
    # No-op to avoid removing reference data used by existing records
  end
end
