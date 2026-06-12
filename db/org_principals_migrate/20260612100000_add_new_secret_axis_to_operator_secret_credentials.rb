# typed: false
# frozen_string_literal: true

class AddNewSecretAxisToOperatorSecretCredentials < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    safety_assured do
      add_column_if_missing :operator_secret_credentials, :secret_kind, :string
      add_column_if_missing :operator_secret_credentials, :usage_policy, :string
      add_column_if_missing :operator_secret_credentials, :lookup_digest, :string
      add_column_if_missing :operator_secret_credentials, :safe_prefix, :string
      add_column_if_missing :operator_secret_credentials, :issued_at, :datetime
      add_column_if_missing :operator_secret_credentials, :issued_by_type, :string
      add_column_if_missing :operator_secret_credentials, :issued_by_id, :bigint
      add_column_if_missing :operator_secret_credentials, :issued_by_ref, :string
      add_column_if_missing :operator_secret_credentials, :delivery_method, :string
      add_column_if_missing :operator_secret_credentials, :scope, :string
      add_column_if_missing :operator_secret_credentials, :use_count, :integer, null: false, default: 0
      add_column_if_missing :operator_secret_credentials, :failure_count, :integer, null: false, default: 0
      add_column_if_missing :operator_secret_credentials, :max_uses, :integer
      add_column_if_missing :operator_secret_credentials, :max_failures, :integer
      add_column_if_missing :operator_secret_credentials, :not_before_at, :datetime
      add_column_if_missing :operator_secret_credentials, :consumed_at, :datetime
      add_column_if_missing :operator_secret_credentials, :revoked_at, :datetime
      add_column_if_missing :operator_secret_credentials, :locked_at, :datetime
      add_column_if_missing :operator_secret_credentials, :last_failed_at, :datetime

      add_index :operator_secret_credentials, :lookup_digest, algorithm: :concurrently, if_not_exists: true
    end
  end

  private

  def add_column_if_missing(table_name, column_name, type, **options)
    add_column table_name, column_name, type, **options unless column_exists?(table_name, column_name)
  end
end
