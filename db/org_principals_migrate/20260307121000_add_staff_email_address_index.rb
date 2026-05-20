# frozen_string_literal: true

class AddStaffEmailAddressIndex < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  INDEX_NAME = :index_staff_emails_on_address

  def up
    add_index(:staff_emails, :address, name: INDEX_NAME, algorithm: :concurrently) unless index_exists?(
      :staff_emails,
      :address, name: INDEX_NAME,
    )
  end

  def down
    remove_index(:staff_emails, name: INDEX_NAME, algorithm: :concurrently, if_exists: true)
  end
end
