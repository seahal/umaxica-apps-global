# frozen_string_literal: true

class RemoveEncryptedIdentifierLookupIndexesFromUserIdentities < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    remove_index(:user_emails, name: :index_user_identity_emails_on_lower_address, algorithm: :concurrently, if_exists: true)
    remove_index(:user_telephones, name: :index_user_telephones_on_lower_number, algorithm: :concurrently, if_exists: true)
  end

  def down
    add_index(
      :user_emails,
      "lower((address)::text)",
      unique: true,
      name: :index_user_identity_emails_on_lower_address,
      algorithm: :concurrently,
      if_not_exists: true,
    )
    add_index(
      :user_telephones,
      "lower((number)::text)",
      unique: true,
      name: :index_user_telephones_on_lower_number,
      algorithm: :concurrently,
      if_not_exists: true,
    )
  end
end
