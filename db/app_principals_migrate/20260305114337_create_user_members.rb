# frozen_string_literal: true

class CreateUserMembers < ActiveRecord::Migration[8.2]
  def change
    create_table(:user_members) do |t|
      t.bigint(:user_id, null: false)
      t.bigint(:member_id, null: false)

      t.timestamps
    end

    add_index(:user_members, [:user_id, :member_id], unique: true)
    add_index(:user_members, :user_id)
    add_index(:user_members, :member_id)

    add_foreign_key(:user_members, :users, on_delete: :cascade, validate: false) if table_exists?(:users)
    add_foreign_key(:user_members, :members, on_delete: :cascade, validate: false) if table_exists?(:members)
  end
end
