# frozen_string_literal: true

class RestoreWorkspacesTable < ActiveRecord::Migration[8.2]
  def change
    create_table(:workspaces) do |t|
      t.string(:name, null: false, default: "")
      t.string(:domain, null: false, default: "")
      t.uuid(:parent_organization, null: false, default: "00000000-0000-0000-0000-000000000000")
      t.timestamps

      t.bigint(:department_id)
      t.bigint(:parent_id)
      t.string(:workspace_status_id, limit: 255)
      t.bigint(:admin_id)

      t.index(:domain, unique: true)
      t.index(:department_id)
      t.index(:parent_id)
      t.index(:workspace_status_id)
      t.index(:admin_id)
    end
  end
end
