# frozen_string_literal: true

class AddWithdrawalStateToCustomers < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_column :customers, :withdrawal_started_at, :datetime unless column_exists?(:customers, :withdrawal_started_at)
    add_column :customers, :scheduled_purge_at, :datetime unless column_exists?(:customers, :scheduled_purge_at)

    add_index :customers,
              :withdrawal_started_at,
              where: "withdrawal_started_at IS NOT NULL",
              name: "index_customers_on_withdrawal_started_at",
              algorithm: :concurrently unless index_exists?(
                :customers,
                :withdrawal_started_at,
                where: "withdrawal_started_at IS NOT NULL",
                name: "index_customers_on_withdrawal_started_at",
              )

    add_index :customers,
              :scheduled_purge_at,
              where: "scheduled_purge_at IS NOT NULL",
              name: "index_customers_on_scheduled_purge_at",
              algorithm: :concurrently unless index_exists?(
                :customers,
                :scheduled_purge_at,
                where: "scheduled_purge_at IS NOT NULL",
                name: "index_customers_on_scheduled_purge_at",
              )
  end
end
