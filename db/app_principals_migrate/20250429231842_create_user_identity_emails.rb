# frozen_string_literal: true

class CreateUserIdentityEmails < ActiveRecord::Migration[8.0]
  def change
    create_table(:user_identity_emails) do |t|
      t.references(:user, type: :bigint, foreign_key: true)
      t.string(:address)
      t.timestamps
    end
  end
end
