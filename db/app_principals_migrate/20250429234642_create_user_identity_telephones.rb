# frozen_string_literal: true

class CreateUserIdentityTelephones < ActiveRecord::Migration[8.0]
  def change
    create_table(:user_identity_telephones) do |t|
      t.references(:user, type: :bigint, foreign_key: true)
      t.string(:number)

      t.timestamps
    end
  end
end
