# frozen_string_literal: true

class CreateAdmins < ActiveRecord::Migration[8.2]
  def change
    create_table(:operators) do |t|
      t.string(:public_id)
      t.string(:moniker)

      t.timestamps
    end
    add_index(:operators, :public_id, unique: true)
  end
end
