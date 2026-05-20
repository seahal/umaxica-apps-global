# typed: false
# frozen_string_literal: true

class RenameGoogleOauth2ProviderToGoogleApp < ActiveRecord::Migration[8.1]
  def up
    safety_assured do
      execute(<<~SQL.squish)
        UPDATE user_social_googles
        SET provider = 'google_app'
        WHERE provider = 'google_oauth2'
      SQL

      change_column_default(:user_social_googles, :provider, from: "google_oauth2", to: "google_app")
    end
  end

  def down
    safety_assured do
      execute(<<~SQL.squish)
        UPDATE user_social_googles
        SET provider = 'google_oauth2'
        WHERE provider = 'google_app'
      SQL

      change_column_default(:user_social_googles, :provider, from: "google_app", to: "google_oauth2")
    end
  end
end
