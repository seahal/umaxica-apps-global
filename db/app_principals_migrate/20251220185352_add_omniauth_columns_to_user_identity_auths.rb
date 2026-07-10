# frozen_string_literal: true

class AddOmniauthColumnsToUserIdentityAuths < ActiveRecord::Migration[8.2]
  def change
    # Google
    change_table(:user_google_auths, bulk: true) do |t|
      t.string(:uid, default: "", null: false)
      t.string(:email)
      t.string(:image)
      t.string(:refresh_token)
      t.integer(:expires_at)
      t.string(:provider, default: "google_oauth2")
    end
    change_column_default(:user_google_auths, :uid, from: "", to: nil)

    add_index(:user_google_auths, [:uid, :provider], unique: true)

    # Apple
    change_table(:user_apple_auths, bulk: true) do |t|
      t.string(:uid, default: "", null: false)
      t.string(:email)
      t.string(:image)
      t.string(:refresh_token)
      t.integer(:expires_at)
      t.string(:provider, default: "apple")
    end
    change_column_default(:user_apple_auths, :uid, from: "", to: nil)

    add_index(:user_apple_auths, [:uid, :provider], unique: true)
  end
end
