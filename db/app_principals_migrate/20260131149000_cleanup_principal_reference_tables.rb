# frozen_string_literal: true

class CleanupPrincipalReferenceTables < ActiveRecord::Migration[8.2]
  REFERENCE_TABLES = %w(
    client_statuses
    user_statuses
    user_email_statuses
    user_telephone_statuses
    user_one_time_password_statuses
    user_passkey_statuses
    user_secret_kinds
    user_secret_statuses
    user_social_apple_statuses
    user_social_google_statuses
    user_identity_audit_events
    user_identity_audit_levels
  ).freeze
  TIMESTAMP_COLUMNS = %i(created_at updated_at).freeze

  def up
    REFERENCE_TABLES.each do |table|
      TIMESTAMP_COLUMNS.each do |column|
        safety_assured { remove_column(table, column, :datetime) } if column_exists?(table, column)
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
