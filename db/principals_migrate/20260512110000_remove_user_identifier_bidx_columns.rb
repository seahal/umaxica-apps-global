# frozen_string_literal: true

class RemoveUserIdentifierBidxColumns < ActiveRecord::Migration[8.2]
  def up
    remove_index(:user_emails, name: :index_user_emails_on_address_bidx, if_exists: true)
    remove_index(:user_telephones, name: :index_user_telephones_on_number_bidx, if_exists: true)

    safety_assured do
      remove_column(:user_emails, :address_bidx, :string, if_exists: true)
      remove_column(:user_telephones, :number_bidx, :string, if_exists: true)
    end
  end

  def down
    add_column(:user_emails, :address_bidx, :string, if_not_exists: true)
    add_column(:user_telephones, :number_bidx, :string, if_not_exists: true)

    add_index(
      :user_emails,
      :address_bidx,
      unique: true,
      where: "address_bidx IS NOT NULL",
      name: :index_user_emails_on_address_bidx,
      if_not_exists: true,
    )
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
