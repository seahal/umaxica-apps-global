# frozen_string_literal: true

class RemoveRedundantOccurrenceBodyUniqueIndexes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    remove_index(:email_occurrences, name: "index_email_occurrences_on_body", algorithm: :concurrently) if
      index_exists?(:email_occurrences, name: "index_email_occurrences_on_body")
    remove_index(:ip_occurrences, name: "index_ip_occurrences_on_body", algorithm: :concurrently) if
      index_exists?(:ip_occurrences, name: "index_ip_occurrences_on_body")
    remove_index(:jwt_occurrences, name: "index_jwt_occurrences_on_body", algorithm: :concurrently) if
      index_exists?(:jwt_occurrences, name: "index_jwt_occurrences_on_body")
    remove_index(:telephone_occurrences, name: "index_telephone_occurrences_on_body", algorithm: :concurrently) if
      index_exists?(:telephone_occurrences, name: "index_telephone_occurrences_on_body")
  end

  def down
    add_index(:email_occurrences, :body, name: "index_email_occurrences_on_body", algorithm: :concurrently) unless
      index_exists?(:email_occurrences, name: "index_email_occurrences_on_body")
    add_index(:ip_occurrences, :body, name: "index_ip_occurrences_on_body", algorithm: :concurrently) unless
      index_exists?(:ip_occurrences, name: "index_ip_occurrences_on_body")
    add_index(:jwt_occurrences, :body, name: "index_jwt_occurrences_on_body", algorithm: :concurrently) unless
      index_exists?(:jwt_occurrences, name: "index_jwt_occurrences_on_body")
    add_index(:telephone_occurrences, :body, name: "index_telephone_occurrences_on_body", algorithm: :concurrently) unless
      index_exists?(:telephone_occurrences, name: "index_telephone_occurrences_on_body")
  end
end
