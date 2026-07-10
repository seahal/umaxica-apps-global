# frozen_string_literal: true

class RemoveUserRedundantIndexes < ActiveRecord::Migration[8.2]
  def change
    remove_index(:user_memberships, column: :user_id, name: :index_user_memberships_on_user_id)
  end
end
