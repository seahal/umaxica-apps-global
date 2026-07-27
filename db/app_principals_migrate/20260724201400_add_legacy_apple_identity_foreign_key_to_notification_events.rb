# frozen_string_literal: true

class AddLegacyAppleIdentityForeignKeyToNotificationEvents < ActiveRecord::Migration[8.2]
  def change
    add_foreign_key(:client_apple_notification_events, :client_apple_identities, validate: false)
  end
end
