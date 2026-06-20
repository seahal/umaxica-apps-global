# typed: false
# frozen_string_literal: true

class RenameGoogleAppProviderToGoogle < ActiveRecord::Migration[8.1]
  def up
    safety_assured do
      execute(<<~SQL.squish)
        UPDATE client_google_identities
        SET provider = 'google'
        WHERE provider = 'google_app'
      SQL

      change_column_default(:client_google_identities, :provider, from: "google_app", to: "google")
    end
  end

  def down
    safety_assured do
      execute(<<~SQL.squish)
        UPDATE client_google_identities
        SET provider = 'google_app'
        WHERE provider = 'google'
      SQL

      change_column_default(:client_google_identities, :provider, from: "google", to: "google_app")
    end
  end
end
