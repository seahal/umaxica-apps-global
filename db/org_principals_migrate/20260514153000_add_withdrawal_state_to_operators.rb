# frozen_string_literal: true

class AddWithdrawalStateToOperators < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_column :operators, :withdrawal_started_at, :datetime unless column_exists?(:operators, :withdrawal_started_at)
    add_column :operators, :deactivated_at, :datetime unless column_exists?(:operators, :deactivated_at)

    unless index_exists?(:operators, :withdrawal_started_at, name: "index_operators_on_withdrawal_started_at")
      add_index(
        :operators,
        :withdrawal_started_at,
        where: "withdrawal_started_at IS NOT NULL",
        name: "index_operators_on_withdrawal_started_at",
        algorithm: :concurrently,
      )
    end

    return if index_exists?(:operators, :deactivated_at, name: "index_operators_on_deactivated_at")

    add_index(
      :operators,
      :deactivated_at,
      where: "deactivated_at IS NOT NULL",
      name: "index_operators_on_deactivated_at",
      algorithm: :concurrently,
    )
  end
end
