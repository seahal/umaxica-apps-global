# frozen_string_literal: true

class ValidateLegacyAppleIdentityForeignKeyOnNotificationEvents < ActiveRecord::Migration[8.2]
  def change
    validate_foreign_key(:client_apple_notification_events, :client_apple_identities)
  end
end
