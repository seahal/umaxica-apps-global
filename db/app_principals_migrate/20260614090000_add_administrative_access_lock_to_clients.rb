# frozen_string_literal: true

class AddAdministrativeAccessLockToClients < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_column(:clients, :access_state, :string, null: false, default: "enabled")
    add_column(:clients, :admin_locked_at, :datetime)
    add_column(:clients, :admin_locked_by_operator_id, :bigint)
    add_column(:clients, :admin_locked_reason_code, :string)
    add_column(:clients, :admin_locked_reason_note, :text)
    add_column(:clients, :token_valid_after_at, :datetime)
    add_column(:clients, :reactivated_at, :datetime)

    add_index(:clients, :access_state, algorithm: :concurrently)
    add_index(:clients, :admin_locked_at, where: "admin_locked_at IS NOT NULL", algorithm: :concurrently)
    add_index(:clients, :token_valid_after_at, where: "token_valid_after_at IS NOT NULL", algorithm: :concurrently)

    add_check_constraint(
      :clients,
      "access_state IN ('enabled', 'admin_locked')",
      name: "chk_clients_access_state",
      validate: false,
    )
    add_check_constraint(
      :clients,
      "admin_locked_reason_code IS NULL OR admin_locked_reason_code IN (" \
      "'abuse', 'security_incident', 'chargeback', 'terms_violation', " \
      "'support_request', 'legal_hold', 'operator_error_recovery', 'other')",
      name: "chk_clients_admin_locked_reason_code",
      validate: false,
    )
  end
end
