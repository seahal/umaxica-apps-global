# frozen_string_literal: true

class AddStaffIdentifierBlindIndexes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    unless column_exists?(:staff_emails, :address_bidx)
      add_column :staff_emails, :address_bidx, :string
    end
    unless column_exists?(:staff_emails, :address_digest)
      add_column :staff_emails, :address_digest, :string
    end
    add_index :staff_emails, :address_bidx, unique: true, where: "address_bidx IS NOT NULL", name: "index_staff_emails_on_address_bidx", algorithm: :concurrently unless index_exists?(:staff_emails, :address_bidx)
    add_index :staff_emails, :address_digest, unique: true, where: "address_digest IS NOT NULL", name: "index_staff_emails_on_address_digest", algorithm: :concurrently unless index_exists?(:staff_emails, :address_digest)

    unless column_exists?(:staff_telephones, :number_bidx)
      add_column :staff_telephones, :number_bidx, :string
    end
    unless column_exists?(:staff_telephones, :number_digest)
      add_column :staff_telephones, :number_digest, :string
    end
    add_index :staff_telephones, :number_bidx, unique: true, where: "number_bidx IS NOT NULL", name: "index_staff_telephones_on_number_bidx", algorithm: :concurrently unless index_exists?(:staff_telephones, :number_bidx)
    add_index :staff_telephones, :number_digest, unique: true, where: "number_digest IS NOT NULL", name: "index_staff_telephones_on_number_digest", algorithm: :concurrently unless index_exists?(:staff_telephones, :number_digest)
  end
end
