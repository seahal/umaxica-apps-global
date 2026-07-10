# frozen_string_literal: true

class ConvertAllOperatorPksToBigint < ActiveRecord::Migration[8.2]
  def up
    # Enable citext extension if not already enabled
    enable_extension("citext") unless extension_enabled?("citext")

    # Drop all operator tables with int/serial/string PKs
    drop_table(:operator_statuses, if_exists: true, force: :cascade)
    drop_table(:staff_statuses, if_exists: true, force: :cascade)
    drop_table(:organization_statuses, if_exists: true, force: :cascade)
    drop_table(:division_statuses, if_exists: true, force: :cascade)
    drop_table(:workspace_statuses, if_exists: true, force: :cascade)
    drop_table(:staff_email_statuses, if_exists: true, force: :cascade)
    drop_table(:staff_telephone_statuses, if_exists: true, force: :cascade)
    drop_table(:staff_secret_statuses, if_exists: true, force: :cascade)
    drop_table(:staff_passkey_statuses, if_exists: true, force: :cascade)
    drop_table(:staff_one_time_password_statuses, if_exists: true, force: :cascade)
    drop_table(:staff_identity_statuses, if_exists: true, force: :cascade)

    # Recreate all tables with bigint PK + code column
    create_table(:operator_statuses, id: :bigint) do |t|
      t.citext(:code, null: false, index: { unique: true })
    end

    create_table(:staff_statuses, id: :bigint) do |t|
      t.citext(:code, null: false, index: { unique: true })
    end

    create_table(:organization_statuses, id: :bigint) do |t|
      t.citext(:code, null: false, index: { unique: true })
    end

    create_table(:division_statuses, id: :bigint) do |t|
      t.citext(:code, null: false, index: { unique: true })
    end

    create_table(:workspace_statuses, id: :bigint) do |t|
      t.citext(:code, null: false, index: { unique: true })
    end

    create_table(:staff_email_statuses, id: :bigint) do |t|
      t.citext(:code, null: false, index: { unique: true })
    end

    create_table(:staff_telephone_statuses, id: :bigint) do |t|
      t.citext(:code, null: false, index: { unique: true })
    end

    create_table(:staff_secret_statuses, id: :bigint) do |t|
      t.citext(:code, null: false, index: { unique: true })
    end

    create_table(:staff_passkey_statuses, id: :bigint) do |t|
      t.citext(:code, null: false, index: { unique: true })
    end

    create_table(:staff_one_time_password_statuses, id: :bigint) do |t|
      t.citext(:code, null: false, index: { unique: true })
    end

    create_table(:staff_identity_statuses, id: :bigint) do |t|
      t.citext(:code, null: false, index: { unique: true })
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "This migration drops data and cannot be reversed"
  end
end
