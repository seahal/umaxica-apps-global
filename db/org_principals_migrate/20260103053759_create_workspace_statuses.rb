# frozen_string_literal: true

class CreateWorkspaceStatuses < ActiveRecord::Migration[8.2]
  def change
    create_table(:workspace_statuses, id: :string, limit: 255) do |t|
      t.timestamps
    end
  end
end
