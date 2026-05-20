# frozen_string_literal: true

# Validates every remaining NOT VALID FK in org_principal. See the
# app_principal counterpart for the rationale (schema:load keeps the
# historical two-step validation from ever completing).
class ValidateRemainingOrgPrincipalForeignKeys < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  FOREIGN_KEYS = [
    [:departments, :departments, :parent_id],
    [:operator_accounts, :departments, :department_id],
    [:operator_accounts, :operators, :staff_id],
    [:operators, :staff_multi_factor_statuses, :multi_factor_status_id],
    [:operators, :staff_multi_factors, :multi_factor_id],
    [:role_assignments, :operators, :staff_id],
    [:staff_banners, :operators, :staff_id],
    [:staff_emails, :operators, :staff_id],
    [:staff_identity_audits, :operators, :staff_id],
    [:staff_identity_audits, :staff_identity_audit_events, :event_id],
    [:staff_identity_passkeys, :operators, :staff_id],
    [:staff_operators, :operator_accounts, :operator_id],
    [:staff_operators, :operators, :staff_id],
    [:staff_passkeys, :operators, :staff_id],
    [:staff_passkeys, :staff_passkey_statuses, :status_id],
    [:staff_recovery_codes, :operators, :staff_id],
    [:staff_secrets, :operators, :staff_id],
    [:staff_telephones, :operators, :staff_id],
    [:user_workspaces, :workspaces, :workspace_id],
  ].freeze

  def up
    FOREIGN_KEYS.each do |from_table, to_table, column|
      next unless foreign_key_exists?(from_table, to_table, column: column)

      validate_foreign_key(from_table, to_table, column: column)
    end
  end

  def down
    # NOT VALID -> VALID is not meaningfully reversible; intentionally a no-op.
  end
end
