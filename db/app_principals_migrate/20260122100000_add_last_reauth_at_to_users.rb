# frozen_string_literal: true

class AddLastReauthAtToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column(:users, :last_reauth_at, :datetime, null: true)
  end
end
