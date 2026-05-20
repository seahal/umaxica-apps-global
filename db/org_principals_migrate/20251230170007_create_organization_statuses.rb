# frozen_string_literal: true

class CreateOrganizationStatuses < ActiveRecord::Migration[8.2]
  def change
    create_table(:organization_statuses, id: :string, limit: 255) do |t|
      t.timestamps
    end
  end
end
