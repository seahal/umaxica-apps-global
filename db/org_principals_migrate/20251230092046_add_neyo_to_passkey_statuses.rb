# frozen_string_literal: true

class AddNeyoToPasskeyStatuses < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  PASSKEY_STATUS_TABLES = %w(
    staff_identity_passkey_statuses
    user_identity_passkey_statuses
  ).freeze

  def up
    safety_assured do
      PASSKEY_STATUS_TABLES.each do |table|
        seed_id(table, "NEYO")
      end
    end
  end

  def down
    # No-op to avoid removing shared reference data.
  end

  private

  def seed_id(table_name, id)
    return unless table_exists?(table_name)

    cols = ["id"]
    vals = [connection.quote(id)]

    if column_exists?(table_name, :created_at)
      cols << "created_at"
      vals << "CURRENT_TIMESTAMP"
    end

    return unless column_exists?(table_name, :updated_at)

    cols << "updated_at"
    vals << "CURRENT_TIMESTAMP"

  end
end
