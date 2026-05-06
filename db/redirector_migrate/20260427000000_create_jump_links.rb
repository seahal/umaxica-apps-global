# typed: false
# frozen_string_literal: true

class CreateJumpLinks < ActiveRecord::Migration[8.2]
  def change
    create_jump_link_table :app_jump_links
    create_jump_link_table :com_jump_links
    create_jump_link_table :org_jump_links
  end

  private

  def create_jump_link_table(table_name)
    create_table table_name do |t|
      t.string :public_id, null: false
      t.text :destination_url, null: false
      t.integer :status_id, null: false, default: 0
      t.datetime :revoked_at, null: false
      t.datetime :deletable_at, null: false
      t.integer :max_uses, null: false, default: 0
      t.integer :uses_count, null: false, default: 0
      t.jsonb :policy, null: false, default: {}

      t.timestamps null: false
    end

    add_index table_name, :public_id, unique: true
    add_index table_name, :status_id
    add_index table_name, :deletable_at
  end
end
