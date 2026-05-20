# frozen_string_literal: true

class FixOperatorFksAndPks < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      enable_extension('citext') unless extension_enabled?('citext')

      # 1. Fix department_status_id: currently string, needs to be bigint FK
      #    department_statuses.id is string PK -> we need to recreate as bigint
      fix_department_status

      # 2. Fix staff_one_time_password_status_id: currently string, needs to be bigint FK
      fix_staff_otp_status

      # 3. Fix staff_secret_kind: currently string PK, needs to be bigint
      fix_staff_secret_kind

      # 4. Enforce NOT NULL on operators.public_id
      if table_exists?(:operators) && column_exists?(:operators, :public_id)
        execute("UPDATE operators SET public_id = '' WHERE public_id IS NULL OR public_id = ''")
        execute("ALTER TABLE operators ALTER COLUMN public_id SET NOT NULL")
      end

      # 5. Enforce NOT NULL on departments.name
      if table_exists?(:departments) && column_exists?(:departments, :name)
        execute("UPDATE departments SET name = 'Default' WHERE name IS NULL")
        execute("ALTER TABLE departments ALTER COLUMN name SET NOT NULL")
      end

      # 6. Fix StaffEmail/StaffTelephone nullable fields
      fix_staff_email_fields
      fix_staff_telephone_fields

      # 7. Fix StaffPasskey nullable fields
      fix_staff_passkey_fields

      # 8. Fix StaffSecret.name NOT NULL
      if table_exists?(:staff_secrets) && column_exists?(:staff_secrets, :name)
        execute("UPDATE staff_secrets SET name = 'secret' WHERE name IS NULL")
        execute("ALTER TABLE staff_secrets ALTER COLUMN name SET NOT NULL")
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def fix_department_status
    # department_statuses has string PK, needs to be bigint
    return unless table_exists?(:department_statuses)

    # First, truncate departments so we can recreate department_statuses
    execute("TRUNCATE TABLE departments CASCADE") if table_exists?(:departments)

    # Drop old FK from departments if exists
    drop_fks_from_table(:departments, :department_statuses)

    # Recreate department_statuses with bigint PK
    drop_table(:department_statuses, force: :cascade)
    create_table(:department_statuses) do |t|
      t.citext(:code, null: false)
      t.index(:code, unique: true)
    end

    # Convert departments.department_status_id from string to bigint
    return unless table_exists?(:departments)

    execute("ALTER TABLE departments ALTER COLUMN department_status_id DROP DEFAULT")
    execute("ALTER TABLE departments ALTER COLUMN department_status_id TYPE bigint USING 0")
    execute("ALTER TABLE departments ALTER COLUMN department_status_id SET DEFAULT 0")
    execute("ALTER TABLE departments ALTER COLUMN department_status_id SET NOT NULL")

    add_fk_sql(:departments, :department_statuses, :department_status_id)

  end

  def fix_staff_otp_status
    # staff_one_time_password_statuses has bigint PK (correct)
    # but staff_one_time_passwords.staff_one_time_password_status_id is string
    return unless table_exists?(:staff_one_time_passwords)

    execute("TRUNCATE TABLE staff_one_time_passwords CASCADE")

    return unless column_exists?(:staff_one_time_passwords, :staff_one_time_password_status_id)

    execute("ALTER TABLE staff_one_time_passwords ALTER COLUMN staff_one_time_password_status_id DROP DEFAULT")
    execute("ALTER TABLE staff_one_time_passwords ALTER COLUMN staff_one_time_password_status_id TYPE bigint USING 0")
    execute("ALTER TABLE staff_one_time_passwords ALTER COLUMN staff_one_time_password_status_id SET DEFAULT 0")
    execute("ALTER TABLE staff_one_time_passwords ALTER COLUMN staff_one_time_password_status_id SET NOT NULL")

    add_fk_sql(:staff_one_time_passwords, :staff_one_time_password_statuses, :staff_one_time_password_status_id)

  end

  def fix_staff_secret_kind
    # staff_secret_kinds has string PK, needs bigint
    return unless table_exists?(:staff_secret_kinds)

    # Truncate referencing table
    execute("TRUNCATE TABLE staff_secrets CASCADE") if table_exists?(:staff_secrets)

    # Drop old FK
    drop_fks_from_table(:staff_secrets, :staff_secret_kinds)

    # Recreate with bigint PK
    drop_table(:staff_secret_kinds, force: :cascade)
    create_table(:staff_secret_kinds) do |t|
      t.citext(:code, null: false)
      t.index(:code, unique: true)
    end

    # Convert staff_secrets.staff_secret_kind_id from string to bigint
    return unless table_exists?(:staff_secrets) && column_exists?(:staff_secrets, :staff_secret_kind_id)

    execute("ALTER TABLE staff_secrets ALTER COLUMN staff_secret_kind_id DROP DEFAULT")
    execute("ALTER TABLE staff_secrets ALTER COLUMN staff_secret_kind_id TYPE bigint USING 0")
    execute("ALTER TABLE staff_secrets ALTER COLUMN staff_secret_kind_id SET DEFAULT 0")
    execute("ALTER TABLE staff_secrets ALTER COLUMN staff_secret_kind_id SET NOT NULL")

    add_fk_sql(:staff_secrets, :staff_secret_kinds, :staff_secret_kind_id)

  end

  def fix_staff_email_fields
    return unless table_exists?(:staff_emails)

    # staff_id NOT NULL
    if column_exists?(:staff_emails, :staff_id)
      execute("DELETE FROM staff_emails WHERE staff_id IS NULL")
      execute("ALTER TABLE staff_emails ALTER COLUMN staff_id SET NOT NULL")
    end

    # address NOT NULL (default to empty string)
    if column_exists?(:staff_emails, :address)
      execute("UPDATE staff_emails SET address = '' WHERE address IS NULL")
      execute("ALTER TABLE staff_emails ALTER COLUMN address SET NOT NULL")
    end

    # otp_counter NOT NULL
    if column_exists?(:staff_emails, :otp_counter)
      execute("UPDATE staff_emails SET otp_counter = '' WHERE otp_counter IS NULL")
      execute("ALTER TABLE staff_emails ALTER COLUMN otp_counter SET NOT NULL")
    end

    # otp_private_key NOT NULL
    return unless column_exists?(:staff_emails, :otp_private_key)

    execute("UPDATE staff_emails SET otp_private_key = '' WHERE otp_private_key IS NULL")
    execute("ALTER TABLE staff_emails ALTER COLUMN otp_private_key SET NOT NULL")

  end

  def fix_staff_telephone_fields
    return unless table_exists?(:staff_telephones)

    # staff_id NOT NULL
    if column_exists?(:staff_telephones, :staff_id)
      execute("DELETE FROM staff_telephones WHERE staff_id IS NULL")
      execute("ALTER TABLE staff_telephones ALTER COLUMN staff_id SET NOT NULL")
    end

    # number NOT NULL
    if column_exists?(:staff_telephones, :number)
      execute("UPDATE staff_telephones SET number = '' WHERE number IS NULL")
      execute("ALTER TABLE staff_telephones ALTER COLUMN number SET NOT NULL")
    end

    # otp_counter NOT NULL
    if column_exists?(:staff_telephones, :otp_counter)
      execute("UPDATE staff_telephones SET otp_counter = '' WHERE otp_counter IS NULL")
      execute("ALTER TABLE staff_telephones ALTER COLUMN otp_counter SET NOT NULL")
    end

    # otp_private_key NOT NULL
    return unless column_exists?(:staff_telephones, :otp_private_key)

    execute("UPDATE staff_telephones SET otp_private_key = '' WHERE otp_private_key IS NULL")
    execute("ALTER TABLE staff_telephones ALTER COLUMN otp_private_key SET NOT NULL")

  end

  def fix_staff_passkey_fields
    return unless table_exists?(:staff_passkeys)

    # external_id NOT NULL
    if column_exists?(:staff_passkeys, :external_id)
      execute("UPDATE staff_passkeys SET external_id = '' WHERE external_id IS NULL")
      execute("ALTER TABLE staff_passkeys ALTER COLUMN external_id SET NOT NULL")
    end

    # public_key NOT NULL
    if column_exists?(:staff_passkeys, :public_key)
      execute("UPDATE staff_passkeys SET public_key = '' WHERE public_key IS NULL")
      execute("ALTER TABLE staff_passkeys ALTER COLUMN public_key SET NOT NULL")
    end

    # sign_count NOT NULL (already default 0)
    return unless column_exists?(:staff_passkeys, :sign_count)

    execute("UPDATE staff_passkeys SET sign_count = 0 WHERE sign_count IS NULL")
    execute("ALTER TABLE staff_passkeys ALTER COLUMN sign_count SET NOT NULL")

  end

  def drop_fks_from_table(from_table, to_table)
    return unless table_exists?(from_table) && table_exists?(to_table)

    fk_rows = connection.select_all(<<~SQL.squish)
      SELECT conname FROM pg_constraint#{" "}
      WHERE conrelid = '#{from_table}'::regclass#{" "}
        AND confrelid = '#{to_table}'::regclass
    SQL

    fk_rows.each do |row|
      execute("ALTER TABLE #{from_table} DROP CONSTRAINT #{row["conname"]}")
    end
  rescue => e
    Rails.logger.debug { "Warning dropping FK: #{e.message}" }
  end

  def add_fk_sql(from_table, to_table, column)
    fk_name = "fk_#{from_table}_on_#{column}"
    result = connection.select_value("SELECT 1 FROM pg_constraint WHERE conname = '#{fk_name}'")
    unless result
      execute("ALTER TABLE #{from_table} ADD CONSTRAINT #{fk_name} FOREIGN KEY (#{column}) REFERENCES #{to_table} (id)")
    end
  rescue => e
    Rails.logger.debug { "Error adding FK #{fk_name}: #{e.message}" }
  end
end
