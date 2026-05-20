# frozen_string_literal: true

class CreateDivisionStatuses < ActiveRecord::Migration[8.2]
  def change
    create_table(:division_statuses, id: :string, limit: 255) do |t|
      t.timestamps
    end
  end
end
