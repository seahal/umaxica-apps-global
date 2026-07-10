# frozen_string_literal: true

class CreateMembers < ActiveRecord::Migration[8.2]
  def change
    create_table(:members) do |t|
      t.string(:public_id)
      t.string(:moniker)
      t.bigint(:user_id)
      t.bigint(:division_id)
      t.bigint(:status_id, default: 5, null: false)

      t.timestamps
    end

    add_index(:members, :public_id, unique: true)
    add_index(:members, :user_id)
    add_index(:members, :division_id)
    add_index(:members, :status_id)

    add_foreign_key(:members, :users, column: :user_id, on_delete: :nullify, validate: false) if table_exists?(:users)
    add_foreign_key(:members, :member_statuses, column: :status_id, validate: false) if table_exists?(:member_statuses)
  end
end
