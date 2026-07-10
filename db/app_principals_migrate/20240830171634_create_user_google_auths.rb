# frozen_string_literal: true

class CreateUserGoogleAuths < ActiveRecord::Migration[8.0]
  def change
    create_table(:user_google_auths) do |t|
      t.references(:user, type: :bigint, foreign_key: true)
      t.string(:token)
      t.timestamps
    end
  end
end
