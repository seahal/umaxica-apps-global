# frozen_string_literal: true

class AddNumberDigestToUserTelephones < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  class MigrationUserTelephone < ActiveRecord::Base
    self.table_name = "user_telephones"
  end

  def up
    unless column_exists?(:user_telephones, :number_digest)
      add_column(:user_telephones, :number_digest, :string)
    end

    say_with_time("Backfilling user_telephones.number_digest from number_bidx") do
      MigrationUserTelephone.reset_column_information
      # Intentionally skip validations for data migration

      MigrationUserTelephone
        .where(number_digest: nil)
        .where.not(number_bidx: nil)
        .in_batches(of: 1000) do |batch|
          batch.update_all("number_digest = number_bidx")
        end
    end

    add_index(
      :user_telephones,
      :number_digest,
      unique: true,
      where: "number_digest IS NOT NULL",
      name: :index_user_telephones_on_number_digest,
      if_not_exists: true,
      algorithm: :concurrently,
    )
  end

  def down
    remove_index(:user_telephones, name: :index_user_telephones_on_number_digest, if_exists: true)
    remove_column(:user_telephones, :number_digest, if_exists: true)
  end
end
