# frozen_string_literal: true

class CreateClientProfileTables < ActiveRecord::Migration[8.2]
  def change
    create_table(:client_profile_statuses, id: :bigserial)

    create_table(:client_profiles, id: :bigserial) do |t|
      t.datetime(:created_at, null: false)
      t.bigint(:division_id)
      t.integer(:lock_version, default: 0, null: false)
      t.string(:moniker)
      t.string(:public_id, null: false)
      t.datetime(:updated_at, null: false)
      t.bigint(:user_id)
      t.bigint(:client_status_id, default: 0, null: false)
      t.bigint(:status_id, default: 0, null: false)

      t.index(:client_status_id)
      t.index(:division_id)
      t.index(:public_id, unique: true)
      t.index(:status_id)
      t.index(:user_id)
    end

    add_foreign_key(:client_profiles, :client_profile_statuses, column: :client_status_id, validate: false)
    add_foreign_key(:client_profiles, :client_profile_statuses, column: :status_id, validate: false)
  end
end
