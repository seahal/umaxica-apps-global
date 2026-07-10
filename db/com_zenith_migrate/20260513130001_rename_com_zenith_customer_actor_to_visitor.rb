# frozen_string_literal: true

class RenameComZenithCustomerActorToVisitor < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      rename_column(:client_accounts, :customer_id, :visitor_id) if column_exists?(:client_accounts, :customer_id)
      rename_index(:client_accounts, :index_client_accounts_on_customer_id, :index_client_accounts_on_visitor_id) if
        index_name_exists?(:client_accounts, :index_client_accounts_on_customer_id)
    end
  end

  def down
    safety_assured do
      rename_column(:client_accounts, :visitor_id, :customer_id) if column_exists?(:client_accounts, :visitor_id)
      rename_index(:client_accounts, :index_client_accounts_on_visitor_id, :index_client_accounts_on_customer_id) if
        index_name_exists?(:client_accounts, :index_client_accounts_on_visitor_id)
    end
  end
end
