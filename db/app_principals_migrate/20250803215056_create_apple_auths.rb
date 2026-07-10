# frozen_string_literal: true

class CreateAppleAuths < ActiveRecord::Migration[8.0]
  def change
    create_table(:apple_auths) do |t|
      t.references(:user, null: false, foreign_key: true, type: :bigint)
      t.string(:provider)
      t.string(:uid)
      t.string(:email)
      t.string(:name)
      t.text(:access_token)
      t.text(:refresh_token)
      t.datetime(:expires_at)

      t.timestamps
    end
  end
end
