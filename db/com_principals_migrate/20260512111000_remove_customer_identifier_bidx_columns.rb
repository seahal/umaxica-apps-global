# frozen_string_literal: true

class RemoveCustomerIdentifierBidxColumns < ActiveRecord::Migration[8.2]
  def up
    remove_index(:customer_emails, name: :index_customer_emails_on_address_bidx, if_exists: true)
    remove_index(:customer_telephones, name: :index_customer_telephones_on_number_bidx, if_exists: true)

    safety_assured do
      remove_column(:customer_emails, :address_bidx, :string, if_exists: true)
      remove_column(:customer_telephones, :number_bidx, :string, if_exists: true)
    end
  end

  def down
    add_column(:customer_emails, :address_bidx, :string, if_not_exists: true)
    add_column(:customer_telephones, :number_bidx, :string, if_not_exists: true)

    add_index(
      :customer_emails,
      :address_bidx,
      unique: true,
      where: "address_bidx IS NOT NULL",
      name: :index_customer_emails_on_address_bidx,
      if_not_exists: true,
    )
    add_index(
      :customer_telephones,
      :number_bidx,
      unique: true,
      where: "number_bidx IS NOT NULL",
      name: :index_customer_telephones_on_number_bidx,
      if_not_exists: true,
    )
  end
end
