# frozen_string_literal: true

class AddLastAuthenticatedAtToSocialTables < ActiveRecord::Migration[7.1]
  def change
    add_column(:user_social_googles, :last_authenticated_at, :datetime, null: true)
    add_column(:user_social_apples, :last_authenticated_at, :datetime, null: true)
  end
end
