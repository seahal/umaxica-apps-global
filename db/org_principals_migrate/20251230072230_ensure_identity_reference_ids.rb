# frozen_string_literal: true

class EnsureIdentityReferenceIds < ActiveRecord::Migration[8.2]
  PASSKEY_STATUSES = %w(ACTIVE DISABLED DELETED NEYO).freeze
  NEYO_ONLY_TABLES = %w(
    user_identity_email_statuses
    user_identity_audit_levels
    staff_identity_audit_levels
  ).freeze

  def up
    PASSKEY_STATUSES.each do |id|
      seed_id(:user_identity_passkey_statuses, id)
    end

    NEYO_ONLY_TABLES.each do |table|
      seed_id(table, "NEYO")
    end
  end

  def down
    # No-op to avoid removing shared reference data.
  end

  private

  def seed_id(table_name, _id)
    return unless table_exists?(table_name)

    has_timestamps = column_exists?(table_name, :created_at) && column_exists?(table_name, :updated_at)

    safety_assured do
      if has_timestamps
      else
      end
    end
  end
end
