# frozen_string_literal: true

class RemoveEncryptedIdentifierLookupIndexesFromStaffIdentities < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    remove_index(:staff_emails, name: :index_staff_emails_on_address, algorithm: :concurrently, if_exists: true)
    remove_index(:staff_emails, name: :index_staff_emails_on_lower_address, algorithm: :concurrently, if_exists: true)
    remove_index(:staff_telephones, name: :index_staff_telephones_on_lower_number, algorithm: :concurrently, if_exists: true)
  end

  def down
    add_index(
      :staff_emails,
      :address,
      name: :index_staff_emails_on_address,
      algorithm: :concurrently,
      if_not_exists: true,
    )
    add_index(
      :staff_emails,
      "lower((address)::text)",
      unique: true,
      name: :index_staff_emails_on_lower_address,
      algorithm: :concurrently,
      if_not_exists: true,
    )
    add_index(
      :staff_telephones,
      "lower((number)::text)",
      unique: true,
      name: :index_staff_telephones_on_lower_number,
      algorithm: :concurrently,
      if_not_exists: true,
    )
  end
end
