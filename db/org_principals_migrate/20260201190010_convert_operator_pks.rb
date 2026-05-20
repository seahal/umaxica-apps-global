# frozen_string_literal: true

class ConvertOperatorPks < ActiveRecord::Migration[8.0]
  def up
    # -------------------------------------------------------------------------
    # DEPENDENTS (Drop)
    # -------------------------------------------------------------------------
    drop_table(:staff_emails, if_exists: true)
    drop_table(:staff_telephones, if_exists: true)
    drop_table(:staff_secrets, if_exists: true)
    drop_table(:role_assignments, if_exists: true)
    drop_table(:staff_operators, if_exists: true)
    drop_table(:operators, if_exists: true)
    drop_table(:user_workspaces, if_exists: true)
    drop_table(:user_organizations, if_exists: true) # Old name if persisted
    drop_table(:departments, if_exists: true)
    drop_table(:department_statuses, if_exists: true)
    drop_table(:divisions, if_exists: true)

    drop_table(:staff_identity_audits, if_exists: true)
    drop_table(:staff_identity_emails, if_exists: true)
    drop_table(:staff_identity_passkeys, if_exists: true)
    drop_table(:staff_identity_secrets, if_exists: true)
    drop_table(:staff_identity_telephones, if_exists: true)
    drop_table(:staff_passkeys, if_exists: true)
    drop_table(:staff_recovery_codes, if_exists: true)
    drop_table(:staff_one_time_passwords, if_exists: true)

    # Drop Lookups (if we want to recreate them or just drop dependent tables)
    # We will recreate the main ones.

    drop_table(:workspaces, if_exists: true)
    drop_table(:organizations, if_exists: true)
    drop_table(:staffs, if_exists: true)
    drop_table(:staffs, if_exists: true)

    # Drop Statuses (To be safe and consistent with recreate)
    drop_table(:staff_identity_statuses, if_exists: true)
    drop_table(:staff_identity_email_statuses, if_exists: true)
    drop_table(:staff_identity_telephone_statuses, if_exists: true)
    drop_table(:staff_identity_secret_statuses, if_exists: true)
    drop_table(:staff_identity_passkey_statuses, if_exists: true)
    drop_table(:staff_one_time_password_statuses, if_exists: true)
    drop_table(:workspace_statuses, if_exists: true)
    drop_table(:organization_statuses, if_exists: true)
    drop_table(:division_statuses, if_exists: true)
    drop_table(:staff_identity_audit_events, if_exists: true)
    drop_table(:staff_identity_audit_levels, if_exists: true)
    drop_table(:operator_statuses, if_exists: true)

    # Drop renamed tables (from earlier migration 20260108100600)
    drop_table(:staff_statuses, if_exists: true)
    drop_table(:staff_email_statuses, if_exists: true)
    drop_table(:staff_telephone_statuses, if_exists: true)
    drop_table(:staff_secret_statuses, if_exists: true)
    drop_table(:staff_passkey_statuses, if_exists: true)
    drop_table(:admin_identity_statuses, if_exists: true)
    drop_table(:department_statuses, if_exists: true)

    # -------------------------------------------------------------------------
    # RECREATE (Bigint PK)
    # -------------------------------------------------------------------------

    create_table(:staff_statuses, id: :string)
    create_table(:staff_identity_statuses, id: :string)

    create_table(:staffs) do |t|
      t.string("webauthn_id")
      t.datetime("created_at", null: false)
      t.datetime("updated_at", null: false)
      t.string("public_id")
      t.string("status_id", default: "NEYO", null: false)
      t.datetime("withdrawn_at")
      t.index(["public_id"], name: "index_staffs_on_public_id", unique: true)
      t.index(["status_id"], name: "index_staffs_on_status_id")
      t.index(["withdrawn_at"], name: "index_staffs_on_withdrawn_at", where: "(withdrawn_at IS NOT NULL)")
    end

    create_table(:workspace_statuses, id: :string)

    create_table(:workspaces) do |t|
      t.string("name", null: false)
      t.datetime("created_at", null: false)
      t.datetime("updated_at", null: false)
      # Add other columns if they were present? Assuming defaults
    end

    create_table(:division_statuses, id: :string)

    create_table(:divisions) do |t|
      # Assuming basic fields
      t.string("name")
      t.datetime("created_at", null: false)
      t.datetime("updated_at", null: false)
    end

    create_table(:organization_statuses, id: :string)

    create_table(:organizations) do |t|
      t.string("domain", default: "", null: false)
      t.string("name", default: "", null: false)
      t.bigint("admin_id")
      t.bigint("department_id")
      t.bigint("parent_id")
      t.string("workspace_status_id")
      t.datetime("created_at", null: false)
      t.datetime("updated_at", null: false)
      t.index(["admin_id"], name: "index_organizations_on_admin_id")
      t.index(["department_id"], name: "index_organizations_on_department_id")
      t.index(["domain"], name: "index_organizations_on_domain", unique: true)
      t.index(["parent_id"], name: "index_organizations_on_parent_id")
      t.index(["workspace_status_id"], name: "index_organizations_on_workspace_status_id")
    end

    create_table(:department_statuses, id: :string)

    create_table(:departments) do |t|
      t.string("name")
      t.bigint("workspace_id")
      t.bigint("parent_id")
      t.string("department_status_id")
      t.datetime("created_at", null: false)
      t.datetime("updated_at", null: false)
      t.index(:workspace_id)
      t.index(:parent_id)
      t.index(:department_status_id)
    end

    # User Workspaces
    create_table(:user_workspaces) do |t|
      t.bigint("user_id", null: false)
      t.bigint("workspace_id", null: false)
      t.datetime("created_at", null: false)
      t.datetime("updated_at", null: false)
      t.index(["user_id"], name: "index_user_workspaces_on_user_id")
      t.index(["workspace_id"], name: "index_user_workspaces_on_workspace_id")
    end

    create_table(:role_assignments) do |t|
      t.bigint("user_id")
      t.bigint("staff_id")
      t.bigint("role_id", null: false) # Role is in Principal schema, ID is Bigint.
      # Roles in Principal schema WERE NOT migrated to Bigint in my ConvertPrincipalPks (I checked, it says 'create_table :roles').
      # Wait, I did `create_table :roles` in Principal migration. Default `create_table` uses bigint in Rails 8 unless specified?
      # My Principal migration `create_table :roles` did NOT specify `id: :uuid`.
      # So `roles` in Principal schema IS NOW Bigint.
      # So `role_id` here should be Bigint.

      t.datetime("created_at", null: false)
      t.datetime("updated_at", null: false)

      t.index(["user_id"], name: "index_role_assignments_on_user_id")
      t.index(["staff_id"], name: "index_role_assignments_on_staff_id")
      t.index(["role_id"], name: "index_role_assignments_on_role_id")
    end

    # Operator Statuses

    create_table(:operator_statuses, id: :string)

    # Operators
    create_table(:operators) do |t|
      t.bigint("staff_id", null: false)
      t.bigint("department_id")
      t.string("public_id")
      t.string("moniker")
      t.string("status_id", default: "NEYO", null: false)
      t.integer("lock_version", default: 0, null: false)
      t.timestamps
      t.index(["public_id"], name: "index_operators_on_public_id", unique: true)
      t.index(["staff_id"], name: "index_operators_on_staff_id")
      t.index(["department_id"], name: "index_operators_on_department_id")
      t.index(["status_id"], name: "index_operators_on_status_id")
    end

    # Staff Operators (join table)
    create_table(:staff_operators) do |t|
      t.bigint("staff_id", null: false)
      t.bigint("admin_id", null: false)
      t.timestamps
      t.index(["admin_id"], name: "index_staff_operators_on_admin_id")
      t.index(["staff_id", "admin_id"], name: "index_staff_operators_on_staff_id_and_admin_id", unique: true)
    end

    # Staff Identities

    create_table(:staff_email_statuses, id: :string)

    create_table(:staff_emails) do |t|
      t.bigint("staff_id")
      t.string("address")
      t.string("otp_private_key")
      t.text("otp_counter")
      t.datetime("otp_expires_at")
      t.datetime("otp_last_sent_at")
      t.integer("otp_attempts_count", default: 0, null: false)
      t.datetime("locked_at")
      t.string("status_id", default: "UNVERIFIED", null: false)
      t.timestamps
      t.index(["staff_id"], name: "index_staff_emails_on_staff_id")
      t.index(["status_id"], name: "index_staff_emails_on_status_id")
    end

    create_table(:staff_telephone_statuses, id: :string)

    create_table(:staff_telephones) do |t|
      t.bigint("staff_id")
      t.string("number")
      t.string("otp_private_key")
      t.text("otp_counter")
      t.datetime("otp_expires_at")
      t.integer("otp_attempts_count", default: 0, null: false)
      t.datetime("locked_at")
      t.string("status_id", default: "UNVERIFIED", null: false)
      t.timestamps
      t.index(["staff_id"], name: "index_staff_telephones_on_staff_id")
    end

    create_table(:staff_recovery_codes) do |t|
      t.bigint("staff_id", null: false)
      t.string("recovery_code_digest")
      t.date("expires_in")
      t.timestamps
      t.index(["staff_id"], name: "index_staff_recovery_codes_on_staff_id")
    end

    create_table(:staff_passkeys) do |t|
      t.bigint("staff_id", null: false)
      t.string("external_id")
      t.text("public_key")
      t.integer("sign_count")
      t.string("user_handle")
      t.string("name")
      t.string("transports")
      t.string("status_id", default: "ACTIVE", null: false)
      t.timestamps
      t.index(["staff_id"], name: "index_staff_passkeys_on_staff_id")
      t.index(["external_id"], name: "index_staff_passkeys_on_external_id")
    end

    create_table(:staff_identity_passkeys) do |t|
      t.bigint("staff_id", null: false)
      t.binary("webauthn_id", null: false)
      t.text("public_key", null: false)
      t.string("description", null: false)
      t.bigint("sign_count", default: 0, null: false)
      t.uuid("external_id", null: false)
      t.timestamps
      t.index(["staff_id"], name: "index_staff_identity_passkeys_on_staff_id")
      t.index(["webauthn_id"], unique: true, name: "index_staff_identity_passkeys_on_webauthn_id")
    end

    create_table(:staff_secret_statuses, id: :string)

    create_table(:staff_passkey_statuses, id: :string)

    create_table(:staff_secrets) do |t|
      t.bigint("staff_id", null: false)
      t.string("password_digest")
      t.datetime("last_used_at")
      t.string("name")
      t.string("status_id", default: "ACTIVE", null: false)
      t.timestamps
      t.index(["staff_id"], name: "index_staff_secrets_on_staff_id")
    end

    create_table(:staff_one_time_password_statuses, id: :string)

    create_table(:staff_one_time_passwords) do |t|
      t.bigint("staff_id", null: false)
      # Assuming structure from name, guessing fields similar to user_otp or standard
      t.string("secret_key")
      t.string("staff_one_time_password_status_id")
      t.timestamps
      t.index(["staff_id"], name: "idx_staff_otps_on_staff_id")
    end

    # Audits

    create_table(:staff_identity_audit_events, id: :string)

    create_table(:staff_identity_audits) do |t|
      t.bigint("staff_id", null: false)
      t.string("event_id", null: false)
      t.datetime("timestamp")
      t.string("ip_address")
      t.bigint("actor_id")
      t.string("actor_type")
      t.text("previous_value")
      # current_value removed in migration
      t.timestamps
      t.index(["staff_id"], name: "index_staff_identity_audits_on_staff_id")
    end

    # -------------------------------------------------------------------------
    # Foreign Keys
    # -------------------------------------------------------------------------
    add_foreign_key(:staffs, :staff_statuses, column: :status_id, primary_key: :id, validate: false)
    add_foreign_key(:user_workspaces, :workspaces, validate: false)

    add_foreign_key(:role_assignments, :staffs, on_delete: :cascade, validate: false)
    # add_foreign_key :role_assignments, :users # External? Principal., validate: false
    add_foreign_key(:staff_emails, :staffs, validate: false)
    add_foreign_key(:staff_emails, :staff_email_statuses, column: :status_id, validate: false)
    add_foreign_key(:staff_telephones, :staffs, validate: false)
    add_foreign_key(:staff_telephones, :staff_telephone_statuses, column: :status_id, validate: false)
    add_foreign_key(:staff_recovery_codes, :staffs, validate: false)
    add_foreign_key(:staff_passkeys, :staffs, validate: false)
    add_foreign_key(:staff_passkeys, :staff_passkey_statuses, column: :status_id, validate: false)
    add_foreign_key(:staff_identity_passkeys, :staffs, validate: false)
    add_foreign_key(:staff_secrets, :staffs, validate: false)
    add_foreign_key(:staff_secrets, :staff_secret_statuses, column: :status_id, validate: false)
    add_foreign_key(:staff_identity_audits, :staffs, validate: false)
    add_foreign_key(:staff_identity_audits, :staff_identity_audit_events, column: :event_id, validate: false)

    add_foreign_key(:departments, :department_statuses, column: :department_status_id, validate: false)
    add_foreign_key(:departments, :workspaces, validate: false)
    add_foreign_key(:departments, :departments, column: :parent_id, validate: false)

    add_foreign_key(:operators, :staffs, validate: false)
    add_foreign_key(:operators, :departments, on_delete: :nullify, validate: false)
    add_foreign_key(:operators, :operator_statuses, column: :status_id, validate: false)
    add_foreign_key(:staff_operators, :staffs, on_delete: :cascade, validate: false)
    add_foreign_key(:staff_operators, :operators, column: :admin_id, on_delete: :cascade, validate: false)

    add_foreign_key(
      :organizations, :workspace_statuses, column: :workspace_status_id, on_delete: :restrict,
                                           validate: false,
    )
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
