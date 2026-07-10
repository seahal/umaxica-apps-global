# frozen_string_literal: true

class CreateUserOrganizations < ActiveRecord::Migration[8.2]
  def change
    create_table(:user_organizations) do |t|
      t.references(:user, null: false, type: :bigint)
      t.references(:organization, null: false, foreign_key: true, type: :bigint)

      t.timestamps
    end
  end
end
