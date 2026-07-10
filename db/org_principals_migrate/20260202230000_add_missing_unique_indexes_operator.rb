# frozen_string_literal: true

class AddMissingUniqueIndexesOperator < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    safety_assured do
      # StaffEmail
      unless column_exists?(:staff_emails, :public_id)

        add_column(:staff_emails, :public_id, :string, limit: 21, null: false, default: "")

      end
      execute("DROP INDEX CONCURRENTLY IF EXISTS index_staff_emails_on_public_id")
      execute("CREATE UNIQUE INDEX CONCURRENTLY index_staff_emails_on_public_id ON staff_emails (public_id)")

      execute("DROP INDEX CONCURRENTLY IF EXISTS index_staff_emails_on_lower_address")
      execute("CREATE UNIQUE INDEX CONCURRENTLY index_staff_emails_on_lower_address ON staff_emails (lower(address))")

      # StaffTelephone
      execute("DROP INDEX CONCURRENTLY IF EXISTS index_staff_telephones_on_lower_number")
      execute("CREATE UNIQUE INDEX CONCURRENTLY index_staff_telephones_on_lower_number ON staff_telephones (lower(number))")

      # StaffPasskey
      unless column_exists?(:staff_passkeys, :webauthn_id)
        add_column(:staff_passkeys, :webauthn_id, :string, null: false, default: "")
      end
      execute("DROP INDEX CONCURRENTLY IF EXISTS index_staff_passkeys_on_webauthn_id")
      execute("CREATE UNIQUE INDEX CONCURRENTLY index_staff_passkeys_on_webauthn_id ON staff_passkeys (webauthn_id)")

      # StaffOneTimePassword
      unless column_exists?(:staff_one_time_passwords, :public_id)

        add_column(:staff_one_time_passwords, :public_id, :string, limit: 21, null: false, default: "")

      end
      execute("DROP INDEX CONCURRENTLY IF EXISTS index_staff_one_time_passwords_on_public_id")
      execute("CREATE UNIQUE INDEX CONCURRENTLY index_staff_one_time_passwords_on_public_id ON staff_one_time_passwords (public_id)")

      # Division
      execute("DROP INDEX CONCURRENTLY IF EXISTS index_divisions_on_division_status_id_and_organization_id")
      execute("CREATE UNIQUE INDEX CONCURRENTLY index_divisions_on_division_status_id_and_organization_id ON divisions (division_status_id, organization_id)")

      # Department
      execute("DROP INDEX CONCURRENTLY IF EXISTS index_departments_on_department_status_id_and_parent_id")
      execute("CREATE UNIQUE INDEX CONCURRENTLY index_departments_on_department_status_id_and_parent_id ON departments (department_status_id, parent_id)")
    end
  end

  def down
  end
end
