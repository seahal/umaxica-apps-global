# frozen_string_literal: true

class ChangeStaffIdToUuidInStaffTables < ActiveRecord::Migration[8.2]
  def up
    # Change staff_id in staff_identity_emails
    change_staff_id_type(:staff_identity_emails)

    # Change staff_id in staff_identity_telephones
    change_staff_id_type(:staff_identity_telephones)

    # Change staff_id in staff_recovery_codes
    change_staff_id_type(:staff_recovery_codes)
  end

  def down
    # Revert staff_id in staff_identity_emails
    revert_staff_id_type(:staff_identity_emails)

    # Revert staff_id in staff_identity_telephones
    revert_staff_id_type(:staff_identity_telephones)

    # Revert staff_id in staff_recovery_codes
    revert_staff_id_type(:staff_recovery_codes)
  end

  private

  def change_staff_id_type(table_name)
    return unless table_exists?(table_name)

    # Remove the index first
    remove_index(table_name, :staff_id) if index_exists?(table_name, :staff_id)

    # Remove the foreign key if it exists
    remove_foreign_key(table_name, :staffs) if foreign_key_exists?(table_name, :staffs)

    # Remove the old column and add it back as uuid
    # Warning: This will lose existing data in the staff_id column
    remove_column(table_name, :staff_id, :bigint)
    add_column(table_name, :staff_id, :bigint)

    # Add the index back
    add_index(table_name, :staff_id)

    # Add foreign key constraint when types match
    return unless compatible_foreign_key_type?(table_name, :staff_id, :staffs)

    add_foreign_key(table_name, :staffs)

  end

  def revert_staff_id_type(table_name)
    return unless table_exists?(table_name)

    # Remove the index first
    remove_index(table_name, :staff_id) if index_exists?(table_name, :staff_id)

    # Remove the foreign key
    remove_foreign_key(table_name, :staffs) if foreign_key_exists?(table_name, :staffs)

    # Remove the uuid column and add back as bigint
    remove_column(table_name, :staff_id, :uuid)
    add_column(table_name, :staff_id, :bigint)

    # Add the index back
    add_index(table_name, :staff_id)

    # Add foreign key constraint when types match
    return unless compatible_foreign_key_type?(table_name, :staff_id, :staffs)

    add_foreign_key(table_name, :staffs)

  end

  def compatible_foreign_key_type?(from_table, from_column, to_table)
    return false unless table_exists?(from_table) && table_exists?(to_table)

    from_type = column_type(from_table, from_column)
    to_type = column_type(to_table, :id)
    from_type && to_type && from_type == to_type
  end

  def column_type(table_name, column_name)
    connection.columns(table_name).find { |column| column.name == column_name.to_s }&.type
  end
end
