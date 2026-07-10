# frozen_string_literal: true

class AddAddressDigestToUserEmails < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  class MigrationUserEmail < ActiveRecord::Base
    self.table_name = "user_emails"
  end

  def up
    unless column_exists?(:user_emails, :address_digest)
      add_column(:user_emails, :address_digest, :string)
    end

    say_with_time("Backfilling user_emails.address_digest from address_bidx") do
      MigrationUserEmail.reset_column_information
      # Intentionally skip validations for data migration

      MigrationUserEmail
        .where(address_digest: nil)
        .where.not(address_bidx: nil)
        .in_batches(of: 1000) do |batch|
          batch.update_all("address_digest = address_bidx")
        end
    end

    add_index(
      :user_emails,
      :address_digest,
      unique: true,
      where: "address_digest IS NOT NULL",
      name: :index_user_emails_on_address_digest,
      if_not_exists: true,
      algorithm: :concurrently,
    )
  end

  def down
    remove_index(:user_emails, name: :index_user_emails_on_address_digest, if_exists: true)
    remove_column(:user_emails, :address_digest, if_exists: true)
  end
end
