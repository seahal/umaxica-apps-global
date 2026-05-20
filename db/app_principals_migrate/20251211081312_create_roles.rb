# frozen_string_literal: true

class CreateRoles < ActiveRecord::Migration[8.2]
  def change
    create_table(:roles) do |t|
      t.string(:key)
      t.string(:name)
      t.text(:description)

      t.timestamps
    end
  end
end
