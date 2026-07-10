# frozen_string_literal: true

class AddMissingIndexesToUserIdentities < ActiveRecord::Migration[8.2]
  def change
    add_index(:user_identity_audits, [:actor_type, :actor_id])
  end
end
