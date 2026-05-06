# frozen_string_literal: true

class ConvertAllPrincipalPksToBigint < ActiveRecord::Migration[8.2]
  def up
    # Enable citext extension if not already enabled
    enable_extension("citext") unless extension_enabled?("citext")

    # Drop all principal tables with int/serial/string PKs
    drop_table(:user_statuses, if_exists: true, force: :cascade)
    drop_table(:client_statuses, if_exists: true, force: :cascade)
    drop_table(:user_email_statuses, if_exists: true, force: :cascade)
    drop_table(:user_telephone_statuses, if_exists: true, force: :cascade)
    drop_table(:user_secret_statuses, if_exists: true, force: :cascade)
    drop_table(:user_passkey_statuses, if_exists: true, force: :cascade)
    drop_table(:user_one_time_password_statuses, if_exists: true, force: :cascade)
    drop_table(:user_secret_kinds, if_exists: true, force: :cascade)
    drop_table(:user_token_kinds, if_exists: true, force: :cascade)
    drop_table(:user_token_statuses, if_exists: true, force: :cascade)
    drop_table(:staff_token_kinds, if_exists: true, force: :cascade)
    drop_table(:staff_token_statuses, if_exists: true, force: :cascade)
    drop_table(:user_social_google_statuses, if_exists: true, force: :cascade)
    drop_table(:user_social_apple_statuses, if_exists: true, force: :cascade)

    # Recreate all tables with bigint PK + code column
    create_table(:user_statuses, id: :bigint) do |t|
      t.citext(:code, null: false, index: { unique: true })
    end

    create_table(:client_statuses, id: :bigint) do |t|
      t.citext(:code, null: false, index: { unique: true })
    end

    create_table(:user_email_statuses, id: :bigint) do |t|
      t.citext(:code, null: false, index: { unique: true })
    end

    create_table(:user_telephone_statuses, id: :bigint) do |t|
      t.citext(:code, null: false, index: { unique: true })
    end

    create_table(:user_secret_statuses, id: :bigint) do |t|
      t.citext(:code, null: false, index: { unique: true })
    end

    create_table(:user_passkey_statuses, id: :bigint) do |t|
      t.citext(:code, null: false, index: { unique: true })
    end

    create_table(:user_one_time_password_statuses, id: :bigint) do |t|
      t.citext(:code, null: false, index: { unique: true })
    end

    create_table(:user_secret_kinds, id: :bigint) do |t|
      t.citext(:code, null: false, index: { unique: true })
    end

    create_table(:user_social_google_statuses, id: :bigint) do |t|
      t.citext(:code, null: false, index: { unique: true })
    end

    create_table(:user_social_apple_statuses, id: :bigint) do |t|
      t.citext(:code, null: false, index: { unique: true })
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "This migration drops data and cannot be reversed"
  end
end
