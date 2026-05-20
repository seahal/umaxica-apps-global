# frozen_string_literal: true

class AddPublicIdAndUserStatusIdToUsers < ActiveRecord::Migration[8.2]
  def up
    change_table(:users, bulk: true) do |t|
      t.string(:public_id, limit: 255)
      t.string(:user_status_id, limit: 255, null: false, default: "NONE")
    end
    add_index(:users, :public_id, unique: true)
    add_index(:users, :user_status_id)
    add_foreign_key(:users, :user_identity_statuses, column: :user_status_id, primary_key: :id)
  end

  def down
    remove_foreign_key(:users, :user_identity_statuses)
    remove_index(:users, :user_status_id)
    remove_index(:users, :public_id)
    change_table(:users, bulk: true) do |t|
      t.remove(:user_status_id)
      t.remove(:public_id)
    end
  end
end
