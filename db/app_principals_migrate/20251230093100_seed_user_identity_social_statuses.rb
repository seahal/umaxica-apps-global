# frozen_string_literal: true

class SeedUserIdentitySocialStatuses < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  SOCIAL_STATUS_TABLES = %w(
    user_identity_social_apple_statuses
    user_identity_social_google_statuses
  ).freeze

  SOCIAL_STATUSES = %w(ACTIVE REVOKED DELETED).freeze

  def up
    safety_assured do
      SOCIAL_STATUS_TABLES.each do |table|
        seed_ids(table, SOCIAL_STATUSES)
      end
    end
  end

  def down
    # No-op to avoid removing shared reference data.
  end

  private

  def seed_ids(table_name, ids)
    return unless table_exists?(table_name)

    ids.each do |id|
      seed_id(table_name, id)
    end
  end

  def seed_id(table_name, id)
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
