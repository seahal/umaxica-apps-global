# frozen_string_literal: true

class ReplaceCodeWithFixedIds < ActiveRecord::Migration[8.0]
  def up
    target_tables = {
      operator_statuses: {
        1 => "ACTIVE",
        2 => "NEYO",
      },
      organization_statuses: {
        1 => "NEYO",
      },
      staff_email_statuses: {
        1 => "ACTIVE",
        2 => "DELETED",
        3 => "INACTIVE",
        4 => "NEYO",
        5 => "PENDING",
        6 => "UNVERIFIED",
        7 => "VERIFIED",
      },
      staff_identity_statuses: {
        1 => "ACTIVE",
        2 => "INACTIVE",
        3 => "NEYO",
      },
      staff_one_time_password_statuses: {
        1 => "ACTIVE",
        2 => "DELETED",
        3 => "INACTIVE",
        4 => "NEYO",
        5 => "REVOKED",
      },
      staff_passkey_statuses: {
        1 => "ACTIVE",
        2 => "REVOKED",
      },
      staff_secret_statuses: {
        1 => "ACTIVE",
        2 => "DELETED",
        3 => "EXPIRED",
        4 => "REVOKED",
        5 => "USED",
      },
      staff_statuses: {
        1 => "ACTIVE",
        2 => "NEYO",
      },
      staff_telephone_statuses: {
        1 => "ACTIVE",
        2 => "DELETED",
        3 => "INACTIVE",
        4 => "NEYO",
        5 => "PENDING",
        6 => "UNVERIFIED",
        7 => "VERIFIED",
      },
      workspace_statuses: {
        1 => "NEYO",
      },
      department_statuses: {
        1 => "NEYO",
        2 => "ACTIVE",
        3 => "INACTIVE",
        4 => "DELETED",
      },
      division_statuses: {
        1 => "NEYO",
        2 => "ACTIVE",
        3 => "INACTIVE",
        4 => "DELETED",
      },
      staff_secret_kinds: {
        1 => "NEYO",
        2 => "LOGIN",
      },
    }

    safety_assured do
      target_tables.each do |table_name, mapping|
        # Ensure table exists
        unless table_exists?(table_name)
          create_table(table_name, id: :bigint) do |t|
            t.citext(:code, null: false, index: { unique: true })
          end
        end

        # 1. Truncate table and cascade to clear references
        execute("TRUNCATE TABLE #{table_name} RESTART IDENTITY CASCADE")

        # 2. Insert fixed IDs
        mapping.each do |id, code|
          execute("INSERT INTO #{table_name} (id, code) VALUES (#{id}, '#{code}')")
        end

        # 3. Update sequence
        max_id = mapping.keys.max
        execute("SELECT setval(pg_get_serial_sequence('#{table_name}', 'id'), #{max_id})")

        # 4. Remove code column and index
        remove_column(table_name, :code)
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
