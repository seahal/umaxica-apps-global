# frozen_string_literal: true

class AddWithdrawalStateToUsers < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_column(:users, :withdrawal_started_at, :datetime) unless column_exists?(:users, :withdrawal_started_at)
    add_column(:users, :deactivated_at, :datetime) unless column_exists?(:users, :deactivated_at)
    add_column(:users, :scheduled_purge_at, :datetime) unless column_exists?(:users, :scheduled_purge_at)
    add_column(:users, :purged_at, :datetime) unless column_exists?(:users, :purged_at)

    add_index(
      :users, :withdrawal_started_at, where: "withdrawal_started_at IS NOT NULL",
                                      algorithm: :concurrently,
    ) unless index_exists?(
      :users, :withdrawal_started_at, where: "withdrawal_started_at IS NOT NULL",
    )
    add_index(
      :users, :deactivated_at, where: "deactivated_at IS NOT NULL",
                               algorithm: :concurrently,
    ) unless index_exists?(
      :users, :deactivated_at, where: "deactivated_at IS NOT NULL",
    )
    add_index(
      :users, :scheduled_purge_at, where: "scheduled_purge_at IS NOT NULL",
                                   algorithm: :concurrently,
    ) unless index_exists?(
      :users, :scheduled_purge_at, where: "scheduled_purge_at IS NOT NULL",
    )
    add_index(
      :users, :purged_at, where: "purged_at IS NOT NULL",
                          algorithm: :concurrently,
    ) unless index_exists?(
      :users,
      :purged_at, where: "purged_at IS NOT NULL",
    )
  end
end
