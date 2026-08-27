# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table(:users) do |t|
      t.string(:webauthn_id)
      t.timestamps
    end
  end
end
