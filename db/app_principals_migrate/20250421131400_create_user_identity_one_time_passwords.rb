# frozen_string_literal: true

class CreateUserIdentityOneTimePasswords < ActiveRecord::Migration[8.0]
  def change
    create_table(:user_identity_one_time_passwords, id: false) do |t|
      t.binary(:user_id, null: false) # , foreign_key: true
      t.binary(:hmac_based_one_time_password_id, null: false) # , foreign_key: true
      t.timestamps
    end
  end
end
