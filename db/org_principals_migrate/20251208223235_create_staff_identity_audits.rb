# frozen_string_literal: true

class CreateStaffIdentityAudits < ActiveRecord::Migration[8.2]
  def change
    create_table(:staff_identity_audits) do |t|
      t.references(:staff, null: false, foreign_key: true, type: :bigint)
      t.string(:event_id, null: false, limit: 255)
      t.datetime(:timestamp)
      t.string(:ip_address)
      t.bigint(:actor_id)
      t.text(:previous_value)
      t.text(:current_value)

      t.timestamps
    end
  end
end
