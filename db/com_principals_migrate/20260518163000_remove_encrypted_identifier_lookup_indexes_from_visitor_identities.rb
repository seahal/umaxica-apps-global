# frozen_string_literal: true

class RemoveEncryptedIdentifierLookupIndexesFromVisitorIdentities < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    remove_index(:visitor_emails, name: :index_visitor_emails_on_lower_address, algorithm: :concurrently, if_exists: true)
    remove_index(:visitor_telephones, name: :index_visitor_telephones_on_lower_number, algorithm: :concurrently, if_exists: true)
  end

  def down
    add_index(
      :visitor_emails,
      "lower((address)::text)",
      unique: true,
      name: :index_visitor_emails_on_lower_address,
      algorithm: :concurrently,
      if_not_exists: true,
    )
    add_index(
      :visitor_telephones,
      "lower((number)::text)",
      unique: true,
      name: :index_visitor_telephones_on_lower_number,
      algorithm: :concurrently,
      if_not_exists: true,
    )
  end
end
