# frozen_string_literal: true

class EnforceExpiresAtOnUserIdentitySocials < ActiveRecord::Migration[8.2]
  def change
    change_column_null(:user_identity_social_apples, :expires_at, false)
    change_column_null(:user_identity_social_googles, :expires_at, false)

    add_index(:user_identity_social_apples, :expires_at)
    add_index(:user_identity_social_googles, :expires_at)
  end
end
