# frozen_string_literal: true

class AddMissingIndexesToStaffIdentities < ActiveRecord::Migration[8.2]
  def change
    add_index(:staff_identity_audits, [:actor_type, :actor_id])
  end
end
