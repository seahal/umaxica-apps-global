# frozen_string_literal: true

class FixConsistencyOperators < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      # Delete in order (Children first) preventing FK violations
      %w(
        staff_one_time_passwords staff_passkeys staff_secrets
        staff_emails staff_telephones
        operators
        divisions departments
        organizations
        staffs
        staff_statuses staff_telephone_statuses staff_email_statuses
        staff_secret_statuses staff_secret_kinds
        staff_passkey_statuses
        organization_statuses department_statuses division_statuses operator_statuses
      ).each do |table|
        execute("DELETE FROM #{table}") if table_exists?(table)
      end

      # --- Staff ---
      remove_column(:staffs, :status_id) if column_exists?(:staffs, :status_id)
      add_reference(
        :staffs, :status, foreign_key: { to_table: :staff_statuses }, type: :bigint, default: 0,
                          null: false,
      )

      change_column_null(:staffs, :public_id, false) if column_exists?(:staffs, :public_id)

      # --- Staff Telephone ---
      remove_column(:staff_telephones, :staff_identity_telephone_status_id) if column_exists?(
        :staff_telephones,
        :staff_identity_telephone_status_id,
      )
      add_reference(
        :staff_telephones, :staff_identity_telephone_status,
        foreign_key: { to_table: :staff_telephone_statuses }, type: :bigint, default: 0, null: false,
      )

      # --- Staff Email ---
      remove_column(:staff_emails, :staff_identity_email_status_id) if column_exists?(
        :staff_emails,
        :staff_identity_email_status_id,
      )
      add_reference(
        :staff_emails, :staff_identity_email_status, foreign_key: { to_table: :staff_email_statuses },
                                                     type: :bigint, default: 0, null: false,
      )

      # --- Staff Secret ---
      remove_column(:staff_secrets, :staff_identity_secret_status_id) if column_exists?(
        :staff_secrets,
        :staff_identity_secret_status_id,
      )
      add_reference(
        :staff_secrets, :staff_identity_secret_status, foreign_key: { to_table: :staff_secret_statuses },
                                                       type: :bigint, default: 0, null: false,
      )

      remove_column(:staff_secrets, :staff_secret_kind_id) if column_exists?(:staff_secrets, :staff_secret_kind_id)
      # StaffSecretKind id is string (e.g. "LOGIN")
      add_reference(
        :staff_secrets, :staff_secret_kind, foreign_key: { to_table: :staff_secret_kinds }, type: :string,
                                            default: "LOGIN", null: false,
      )

      # --- Staff Passkey ---
      remove_column(:staff_passkeys, :staff_passkey_status_id) if column_exists?(
        :staff_passkeys,
        :staff_passkey_status_id,
      )
      add_reference(
        :staff_passkeys, :staff_passkey_status, foreign_key: { to_table: :staff_passkey_statuses },
                                                type: :bigint, default: 0, null: false,
      )

      # --- Organization ---
      remove_column(:organizations, :workspace_status_id) if column_exists?(:organizations, :workspace_status_id)
      add_reference(
        :organizations, :workspace_status, foreign_key: { to_table: :organization_statuses },
                                           type: :bigint, default: 0, null: false,
      )

      # --- Department ---
      remove_column(:departments, :department_status_id) if column_exists?(:departments, :department_status_id)
      # department_statuses table uses String ID
      add_reference(
        :departments, :department_status, foreign_key: { to_table: :department_statuses }, type: :string,
                                          default: "ACTIVE", null: false,
      )

      # Fix Department -> Organization (nullify) usually parent_id or workspace_id?
      # Department model: belongs_to :workspace, class_name: "Organization"
      if foreign_key_exists?(:departments, column: :workspace_id)
        remove_foreign_key(:departments, column: :workspace_id)
      end
      if column_exists?(:departments, :workspace_id)
        add_foreign_key(:departments, :organizations, column: :workspace_id, on_delete: :nullify)
      end

      # --- Division ---
      remove_column(:divisions, :division_status_id) if column_exists?(:divisions, :division_status_id)
      # division_statuses table apparently uses Bigint ID (unlike department_statuses)
      add_reference(
        :divisions, :division_status, foreign_key: { to_table: :division_statuses }, type: :bigint,
                                      default: 0, null: false,
      )

      # Fix Division -> Organization (nullify)
      if foreign_key_exists?(:divisions, :organizations)
        remove_foreign_key(:divisions, :organizations)
      end
      if column_exists?(:divisions, :organization_id)
        # Check if FK exists on organization_id explicitly
        if foreign_key_exists?(:divisions, column: :organization_id)
          remove_foreign_key(:divisions, column: :organization_id)
        end
        add_foreign_key(:divisions, :organizations, column: :organization_id, on_delete: :nullify)
      end

      # --- Operator ---
      remove_column(:operators, :status_id) if column_exists?(:operators, :status_id)
      add_reference(
        :operators, :status, foreign_key: { to_table: :operator_statuses }, type: :bigint, default: 0,
                             null: false,
      )
    end
  end

  def down; raise ActiveRecord::IrreversibleMigration; end
end
