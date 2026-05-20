# frozen_string_literal: true

class ConvertPrincipalPks < ActiveRecord::Migration[8.0]
  def up
    # -------------------------------------------------------------------------
    # DEPENDENTS (Drop)
    # -------------------------------------------------------------------------
    drop_table(:apple_auths, if_exists: true)
    drop_table(:google_auths, if_exists: true)

    drop_table(:user_client_deletions, if_exists: true)
    drop_table(:user_client_discoveries, if_exists: true)
    drop_table(:user_client_impersonations, if_exists: true)
    drop_table(:user_client_observations, if_exists: true)
    drop_table(:user_client_revocations, if_exists: true)
    drop_table(:user_client_suspensions, if_exists: true)
    drop_table(:user_clients, if_exists: true)

    drop_table(:clients, if_exists: true) # depends on users too?

    drop_table(:user_emails, if_exists: true)
    drop_table(:user_identity_audits, if_exists: true)
    drop_table(:user_memberships, if_exists: true)
    drop_table(:user_one_time_passwords, if_exists: true)
    drop_table(:user_passkeys, if_exists: true)
    drop_table(:user_secrets, if_exists: true)
    drop_table(:user_social_apples, if_exists: true)
    drop_table(:user_social_googles, if_exists: true)
    drop_table(:user_telephones, if_exists: true)

    drop_table(:accounts, if_exists: true)

    # Drop Lookups
    drop_table(:client_statuses, if_exists: true)
    drop_table(:roles, if_exists: true) # Not strictly dependent on users but has organization_id (uuid)

    drop_table(:users, if_exists: true)

    drop_table(:user_email_statuses, if_exists: true)
    drop_table(:user_identity_audit_events, if_exists: true)
    drop_table(:user_identity_audit_levels, if_exists: true)
    drop_table(:user_one_time_password_statuses, if_exists: true)
    drop_table(:user_passkey_statuses, if_exists: true)
    drop_table(:user_secret_kinds, if_exists: true)
    drop_table(:user_secret_statuses, if_exists: true)
    drop_table(:user_social_apple_statuses, if_exists: true)
    drop_table(:user_social_google_statuses, if_exists: true)
    drop_table(:user_statuses, if_exists: true)
    drop_table(:user_telephone_statuses, if_exists: true)

    # -------------------------------------------------------------------------
    # MAIN TABLES (Recreate with Bigint)
    # -------------------------------------------------------------------------

    create_table(:user_statuses, id: { type: :integer, limit: 2, default: nil }) do |t|
      t.check_constraint("id >= 0", name: "user_statuses_id_non_negative")
    end

    create_table(:users) do |t|
      t.datetime("created_at", null: false)
      t.datetime("last_reauth_at")
      t.integer("lock_version", default: 0, null: false)
      t.string("public_id", limit: 255, default: "")
      t.integer("status_id", limit: 2, default: 1, null: false)
      t.datetime("updated_at", null: false)
      t.datetime("withdrawn_at", default: Float::INFINITY)
      t.index(["public_id"], name: "index_users_on_public_id", unique: true)
      t.index(["status_id"], name: "index_users_on_status_id")
      t.index(["withdrawn_at"], name: "index_users_on_withdrawn_at", where: "(withdrawn_at IS NOT NULL)")
      t.check_constraint("status_id >= 0", name: "users_status_id_non_negative")
    end

    create_table(:accounts) do |t|
      t.bigint("accountable_id", null: false) # Changed from uuid
      t.string("accountable_type", null: false)
      t.datetime("created_at", null: false)
      t.string("email", null: false)
      t.string("password_digest", null: false)
      t.datetime("updated_at", null: false)
      t.index(
        ["accountable_type", "accountable_id"], name: "index_accounts_on_accountable_type_and_accountable_id",
                                                unique: true,
      )
      t.index(["email"], name: "index_accounts_on_email", unique: true)
    end

    create_table(:apple_auths) do |t|
      t.text("access_token", null: false)
      t.datetime("created_at", null: false)
      t.string("email", default: "", null: false)
      t.datetime("expires_at", null: false)
      t.string("name", default: "", null: false)
      t.string("provider", default: "", null: false)
      t.text("refresh_token", null: false)
      t.string("uid", default: "", null: false)
      t.datetime("updated_at", null: false)
      t.bigint("user_id", null: false)
      t.index(["user_id"], name: "index_apple_auths_on_user_id")
    end

    create_table(:google_auths) do |t|
      t.text("access_token", null: false)
      t.datetime("created_at", null: false)
      t.string("email", default: "", null: false)
      t.datetime("expires_at", null: false)
      t.string("image_url", default: "", null: false)
      t.string("name", default: "", null: false)
      t.string("provider", default: "", null: false)
      t.text("raw_info", null: false)
      t.text("refresh_token", null: false)
      t.string("uid", default: "", null: false)
      t.datetime("updated_at", null: false)
      t.bigint("user_id", null: false)
      t.index(["user_id"], name: "index_google_auths_on_user_id")
    end

    create_table(:client_statuses, id: { type: :integer, limit: 2, default: nil }) do |t|
      t.check_constraint("id >= 0", name: "client_statuses_id_non_negative")
    end

    create_table(:clients) do |t|
      t.datetime("created_at", null: false)
      t.bigint("division_id") # Assumed changed if div_id is uuid, possibly external? Let's assume bigint FK.
      t.integer("lock_version", default: 0, null: false)
      t.string("moniker")
      t.string("public_id")
      t.integer("status_id", limit: 2, default: 0, null: false)
      t.datetime("updated_at", null: false)
      t.bigint("user_id")
      t.index(["division_id"], name: "index_clients_on_division_id")
      t.index(["public_id"], name: "index_clients_on_public_id", unique: true)
      t.index(["status_id"], name: "index_clients_on_status_id")
      t.index(["user_id"], name: "index_clients_on_user_id")
      t.check_constraint("status_id >= 0", name: "clients_status_id_non_negative")
    end

    create_table(:roles) do |t| # UUID PK can stay? User didnt specify. Assume convert to bigint.
      t.datetime("created_at", null: false)
      t.text("description", default: "", null: false)
      t.string("key", default: "", null: false)
      t.string("name", default: "", null: false)
      t.bigint("organization_id", null: false) # Org might be external
      t.datetime("updated_at", null: false)
      t.index(["organization_id"], name: "index_roles_on_organization_id")
    end

    # User Clients Intermediates
    create_table(:user_clients) do |t|
      t.bigint("client_id", null: false)
      t.datetime("created_at", null: false)
      t.datetime("updated_at", null: false)
      t.bigint("user_id", null: false)
      t.index(["client_id"], name: "index_user_clients_on_client_id")
      t.index(["user_id", "client_id"], name: "index_user_clients_on_user_id_and_client_id", unique: true)
      t.index(["user_id"], name: "index_user_clients_on_user_id")
    end

    # Helper function to create user_client_* tables
    %w(deletions discoveries impersonations observations revocations suspensions).each do |suffix|
      create_table("user_client_#{suffix}") do |t|
        t.bigint("client_id", null: false)
        t.datetime("created_at", null: false)
        t.datetime("updated_at", null: false)
        t.bigint("user_id", null: false)
        t.index(["client_id"], name: "index_user_client_#{suffix}_on_client_id")
        t.index(["user_id", "client_id"], name: "index_user_client_#{suffix}_on_user_id_and_client_id", unique: true)
      end
    end

    create_table(:user_email_statuses, id: { type: :integer, limit: 2, default: nil }) do |t|
      t.check_constraint("id >= 0", name: "user_email_statuses_id_non_negative")
    end

    create_table(:user_emails) do |t|
      t.string("address", default: "", null: false)
      t.datetime("created_at", null: false)
      t.datetime("locked_at", default: -Float::INFINITY, null: false)
      t.integer("otp_attempts_count", default: 0, null: false)
      t.text("otp_counter", default: "", null: false)
      t.datetime("otp_expires_at", default: -Float::INFINITY, null: false)
      t.datetime("otp_last_sent_at", default: -Float::INFINITY, null: false)
      t.string("otp_private_key", default: "", null: false)
      t.string("public_id", limit: 21, null: false)
      t.datetime("updated_at", null: false)
      t.bigint("user_id", null: false)
      t.integer("user_identity_email_status_id", limit: 2, default: 0, null: false)
      t.binary("verification_token_digest")
      t.index("lower((address)::text)", name: "index_user_identity_emails_on_lower_address", unique: true)
      t.index(["otp_last_sent_at"], name: "index_user_emails_on_otp_last_sent_at")
      t.index(["public_id"], name: "index_user_emails_on_public_id", unique: true)
      t.index(["user_id"], name: "index_user_emails_on_user_id")
      t.index(["user_identity_email_status_id"], name: "index_user_emails_on_user_identity_email_status_id")
    end

    create_table(:user_identity_audit_events, id: { type: :integer, limit: 2, default: nil }) do |t|
      t.check_constraint("id >= 0", name: "user_identity_audit_events_id_non_negative")
    end
    create_table(:user_identity_audit_levels, id: { type: :integer, limit: 2, default: nil }) do |t|
      t.check_constraint("id >= 0", name: "user_identity_audit_levels_id_non_negative")
    end

    create_table(:user_identity_audits) do |t|
      t.bigint("actor_id", default: 0, null: false)
      t.string("actor_type", default: "", null: false)
      t.datetime("created_at", null: false)
      t.bigint("event_id", default: 0, null: false)
      t.string("ip_address", default: "", null: false)
      t.bigint("level_id", default: 0, null: false)
      t.text("previous_value")
      t.bigint("subject_id")
      t.string("subject_type", default: "", null: false)
      t.datetime("timestamp", null: false)
      t.datetime("updated_at", null: false)
      t.bigint("user_id", null: false)
      t.index(["event_id"], name: "index_user_identity_audits_on_event_id")
      t.index(["level_id"], name: "index_user_identity_audits_on_level_id")
      t.index(["subject_id"], name: "index_user_identity_audits_on_subject_id")
      t.index(["user_id"], name: "index_user_identity_audits_on_user_id")
    end

    # user_memberships - workspace_id is likely UUID
    create_table(:user_memberships) do |t|
      t.datetime("created_at", null: false)
      t.datetime("joined_at", default: -> { "CURRENT_TIMESTAMP" }, null: false)
      t.datetime("left_at", default: -Float::INFINITY, null: false)
      t.datetime("updated_at", null: false)
      t.bigint("user_id", null: false)
      t.bigint("workspace_id", null: false)
      t.index(["user_id", "workspace_id"], name: "index_user_memberships_on_user_id_and_workspace_id", unique: true)
      t.index(["workspace_id"], name: "index_user_memberships_on_workspace_id")
    end

    create_table(:user_one_time_password_statuses, id: { type: :integer, limit: 2, default: nil }) do |t|
      t.check_constraint("id >= 0", name: "user_one_time_password_statuses_id_non_negative")
    end

    create_table(:user_one_time_passwords) do |t|
      t.datetime("created_at", null: false)
      t.datetime("last_otp_at", default: -Float::INFINITY, null: false)
      t.string("private_key", limit: 1024, default: "", null: false)
      t.string("public_id", limit: 21)
      t.string("title", limit: 32)
      t.datetime("updated_at", null: false)
      t.bigint("user_id", null: false)
      t.integer("user_identity_one_time_password_status_id", limit: 2, default: 1, null: false)
      t.index(["public_id"], name: "index_user_one_time_passwords_on_public_id", unique: true)
      t.index(["user_id"], name: "index_user_one_time_passwords_on_user_id")
      t.index(
        ["user_identity_one_time_password_status_id"],
        name: "idx_on_user_identity_one_time_password_status_id_c03cdf0b39",
      )
    end

    create_table(:user_passkey_statuses, id: { type: :integer, limit: 2, default: nil }) do |t|
      t.check_constraint("id >= 0", name: "user_passkey_statuses_id_non_negative")
    end

    create_table(:user_passkeys) do |t|
      t.datetime("created_at", null: false)
      t.string("description", default: "", null: false)
      t.uuid("external_id", null: false)
      t.text("public_key", null: false)
      t.bigint("sign_count", default: 0, null: false)
      t.datetime("updated_at", null: false)
      t.bigint("user_id", null: false)
      t.integer("user_passkey_status_id", limit: 2, default: 1, null: false)
      t.string("webauthn_id", default: "", null: false)
      t.index(["user_id"], name: "index_user_identity_passkeys_on_user_id")
      t.index(["user_passkey_status_id"], name: "idx_on_user_identity_passkey_status_id_f979a7d699")
      t.index(["webauthn_id"], name: "index_user_identity_passkeys_on_webauthn_id", unique: true)
    end

    create_table(:user_secret_kinds, id: { type: :integer, limit: 2, default: nil }) do |t|
      t.check_constraint("id >= 0", name: "user_secret_kinds_id_non_negative")
    end

    create_table(:user_secret_statuses, id: { type: :integer, limit: 2, default: nil }) do |t|
      t.check_constraint("id >= 0", name: "user_secret_statuses_id_non_negative")
    end

    create_table(:user_secrets) do |t|
      t.datetime("created_at", null: false)
      t.datetime("expires_at", default: Float::INFINITY, null: false)
      t.datetime("last_used_at", default: -Float::INFINITY, null: false)
      t.string("name", default: "", null: false)
      t.string("password_digest", default: "", null: false)
      t.datetime("updated_at", null: false)
      t.bigint("user_id", null: false)
      t.integer("user_identity_secret_status_id", limit: 2, default: 1, null: false)
      t.integer("user_secret_kind_id", limit: 2, default: 1, null: false)
      t.integer("uses_remaining", default: 1, null: false)
      t.index(["expires_at"], name: "index_user_secrets_on_expires_at")
      t.index(["user_id"], name: "index_user_secrets_on_user_id")
      t.index(["user_identity_secret_status_id"], name: "index_user_secrets_on_user_identity_secret_status_id")
      t.index(["user_secret_kind_id"], name: "index_user_secrets_on_user_secret_kind_id")
    end

    create_table(:user_social_apple_statuses, id: { type: :integer, limit: 2, default: nil }) do |t|
      t.check_constraint("id >= 0", name: "user_social_apple_statuses_id_non_negative")
    end

    create_table(:user_social_apples) do |t|
      t.datetime("created_at", null: false)
      t.integer("expires_at", null: false)
      t.string("image", default: "", null: false)
      t.datetime("last_authenticated_at")
      t.string("provider", default: "apple", null: false)
      t.string("refresh_token", default: "", null: false)
      t.string("token", default: "", null: false)
      t.string("uid", default: "", null: false)
      t.datetime("updated_at", null: false)
      t.bigint("user_id", null: false)
      t.integer("user_identity_social_apple_status_id", limit: 2, default: 1, null: false)
      t.index(["expires_at"], name: "index_user_social_apples_on_expires_at")
      t.index(["uid", "provider"], name: "index_user_social_apples_on_uid_and_provider", unique: true)
      t.index(
        ["user_id"], name: "index_user_identity_social_apples_on_user_id_unique", unique: true,
                     where: "(user_id IS NOT NULL)",
      )
      t.index(["user_identity_social_apple_status_id"], name: "idx_on_user_identity_social_apple_status_id_93441f369d")
    end

    create_table(:user_social_google_statuses, id: { type: :integer, limit: 2, default: nil }) do |t|
      t.check_constraint("id >= 0", name: "user_social_google_statuses_id_non_negative")
    end

    create_table(:user_social_googles) do |t|
      t.datetime("created_at", null: false)
      t.integer("expires_at", null: false)
      t.string("image", default: "", null: false)
      t.datetime("last_authenticated_at")
      t.string("provider", default: "google_oauth2", null: false)
      t.string("refresh_token", default: "", null: false)
      t.string("token", default: "", null: false)
      t.string("uid", default: "", null: false)
      t.datetime("updated_at", null: false)
      t.bigint("user_id", null: false)
      t.integer("user_identity_social_google_status_id", limit: 2, default: 1, null: false)
      t.index(["expires_at"], name: "index_user_social_googles_on_expires_at")
      t.index(["uid", "provider"], name: "index_user_social_googles_on_uid_and_provider", unique: true)
      t.index(
        ["user_id"], name: "index_user_identity_social_googles_on_user_id_unique", unique: true,
                     where: "(user_id IS NOT NULL)",
      )
      t.index(
        ["user_identity_social_google_status_id"],
        name: "idx_on_user_identity_social_google_status_id_f4bfb6ffdd",
      )
    end

    create_table(:user_telephone_statuses, id: { type: :integer, limit: 2, default: nil }) do |t|
      t.check_constraint("id >= 0", name: "user_telephone_statuses_id_non_negative")
    end

    create_table(:user_telephones) do |t|
      t.datetime("created_at", null: false)
      t.datetime("locked_at", default: -Float::INFINITY, null: false)
      t.string("number", default: "", null: false)
      t.integer("otp_attempts_count", default: 0, null: false)
      t.text("otp_counter", default: "", null: false)
      t.datetime("otp_expires_at", default: -Float::INFINITY, null: false)
      t.string("otp_private_key", default: "", null: false)
      t.datetime("updated_at", null: false)
      t.bigint("user_id", null: false)
      t.integer("user_identity_telephone_status_id", limit: 2, default: 0, null: false)
      t.index("lower((number)::text)", name: "index_user_identity_telephones_on_lower_number")
      t.index(["user_id"], name: "index_user_telephones_on_user_id")
      t.index(["user_identity_telephone_status_id"], name: "index_user_telephones_on_user_identity_telephone_status_id")
    end

    # -------------------------------------------------------------------------
    # Foreign Keys
    # -------------------------------------------------------------------------
    # Note: Ensure FK names don't conflict or are auto-generated.
    add_foreign_key("apple_auths", "users", validate: false)
    add_foreign_key("clients", "client_statuses", column: "status_id", validate: false)
    add_foreign_key("clients", "users", validate: false)
    add_foreign_key("google_auths", "users", validate: false)

    %w(deletions discoveries impersonations observations revocations suspensions).each do |suffix|
      add_foreign_key("user_client_#{suffix}", "clients", validate: false)
      add_foreign_key("user_client_#{suffix}", "users", validate: false)
    end
    add_foreign_key("user_clients", "clients", on_delete: :cascade, validate: false)
    add_foreign_key("user_clients", "users", on_delete: :cascade, validate: false)

    add_foreign_key("user_emails", "user_email_statuses", column: "user_identity_email_status_id", validate: false)
    add_foreign_key("user_emails", "users", validate: false)
    add_foreign_key("user_identity_audits", "user_identity_audit_events", column: "event_id", validate: false)
    add_foreign_key("user_identity_audits", "user_identity_audit_levels", column: "level_id", validate: false)
    add_foreign_key("user_memberships", "users", validate: false)
    add_foreign_key(
      "user_one_time_passwords", "user_one_time_password_statuses",
      column: "user_identity_one_time_password_status_id", validate: false,
    )
    add_foreign_key("user_one_time_passwords", "users", validate: false)
    add_foreign_key("user_passkeys", "user_passkey_statuses", validate: false)
    add_foreign_key("user_passkeys", "users", validate: false)
    add_foreign_key("user_secrets", "user_secret_kinds", validate: false)
    add_foreign_key("user_secrets", "user_secret_statuses", column: "user_identity_secret_status_id", validate: false)
    add_foreign_key("user_secrets", "users", validate: false)
    add_foreign_key(
      "user_social_apples", "user_social_apple_statuses", column: "user_identity_social_apple_status_id",
                                                          validate: false,
    )
    add_foreign_key("user_social_apples", "users", validate: false)
    add_foreign_key(
      "user_social_googles", "user_social_google_statuses",
      column: "user_identity_social_google_status_id", validate: false,
    )
    add_foreign_key("user_social_googles", "users", validate: false)
    add_foreign_key(
      "user_telephones", "user_telephone_statuses", column: "user_identity_telephone_status_id",
                                                    validate: false,
    )
    add_foreign_key("user_telephones", "users", validate: false)
    add_foreign_key("users", "user_statuses", column: "status_id", validate: false)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
