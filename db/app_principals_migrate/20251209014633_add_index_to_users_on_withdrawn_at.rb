# frozen_string_literal: true

class AddIndexToUsersOnWithdrawnAt < ActiveRecord::Migration[8.2]
  def change
    if column_exists?(:users, :withdrawn_at)
      add_index(:users, :withdrawn_at, where: "withdrawn_at IS NOT NULL") unless index_exists?(
        :users, :withdrawn_at,
        where: "withdrawn_at IS NOT NULL",
      )
    else
      warn("Skipping add_index :users(:withdrawn_at) — column does not exist")
    end
  end
end
