# frozen_string_literal: true

class AddActorTypeToStaffIdentityAudit < ActiveRecord::Migration[8.2]
  def change
    add_column(:staff_identity_audits, :actor_type, :string)
  end
end
