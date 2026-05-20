# frozen_string_literal: true

class CreateUserClientDeletions < ActiveRecord::Migration[8.2]
  def change
    create_table(:user_client_deletions) do |t|
      t.references(:user, null: false, foreign_key: true, type: :bigint)
      t.references(:client, null: false, foreign_key: true, type: :bigint)

      t.timestamps

      t.index(%i(user_id client_id), unique: true)
    end
  end
end
