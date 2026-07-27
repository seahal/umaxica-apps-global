# frozen_string_literal: true

class AddLegacyAppleIdentityToNotificationEvents < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_reference(
      :client_apple_notification_events,
      :client_apple_identity,
      index: { algorithm: :concurrently },
      foreign_key: false,
    )
  end
end
