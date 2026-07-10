# frozen_string_literal: true

class AddIdentifierBlindIndexesPrincipal < ActiveRecord::Migration[8.2]
  class MigrationUserEmail < ActiveRecord::Base
    self.table_name = "user_emails"
  end

  class MigrationUserTelephone < ActiveRecord::Base
    self.table_name = "user_telephones"
  end

  def up
    ensure_identifier_blind_index_columns

    backfill_user_email_bidx
    backfill_user_telephone_bidx

    ensure_identifier_blind_index_columns

    safety_assured do
      if column_exists?(:user_emails, :address_bidx)
        add_index(
          :user_emails,
          :address_bidx,
          unique: true,
          where: "address_bidx IS NOT NULL",
          name: :index_user_emails_on_address_bidx,
          if_not_exists: true,
        )
      end
      if column_exists?(:user_telephones, :number_bidx)
        add_index(
          :user_telephones,
          :number_bidx,
          unique: true,
          where: "number_bidx IS NOT NULL",
          name: :index_user_telephones_on_number_bidx,
          if_not_exists: true,
        )
      end
    end
  end

  def down
    remove_index(:user_telephones, name: :index_user_telephones_on_number_bidx, if_exists: true)
    remove_index(:user_emails, name: :index_user_emails_on_address_bidx, if_exists: true)

    remove_column(:user_telephones, :number_bidx, if_exists: true)
    remove_column(:user_emails, :address_bidx, if_exists: true)
  end

  private

  def backfill_user_email_bidx
    say_with_time("Backfilling user_emails.address_bidx") do
      MigrationUserEmail.reset_column_information
      MigrationUserEmail.find_each(batch_size: 1000) do |record|
        bidx = IdentifierBlindIndex.bidx_for_email(record.address)
        next if bidx.blank? || record.address_bidx == bidx

        record.update!(address_bidx: bidx)
      end
    end
  end

  def backfill_user_telephone_bidx
    say_with_time("Backfilling user_telephones.number_bidx") do
      MigrationUserTelephone.reset_column_information
      MigrationUserTelephone.find_each(batch_size: 1000) do |record|
        bidx = IdentifierBlindIndex.bidx_for_telephone(record.number)
        next if bidx.blank? || record.number_bidx == bidx

        record.update!(number_bidx: bidx)
      end
    end
  end

  def ensure_identifier_blind_index_columns
    unless column_exists?(:user_emails, :address_bidx)
      add_column(:user_emails, :address_bidx, :string, if_not_exists: true)
    end

    return if column_exists?(:user_telephones, :number_bidx)

    add_column(:user_telephones, :number_bidx, :string, if_not_exists: true)

  end
end
