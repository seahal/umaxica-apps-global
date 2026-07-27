# frozen_string_literal: true

class AddClientToAppleNotificationEvents < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_reference(
      :client_apple_notification_events,
      :client,
      index: { algorithm: :concurrently },
      foreign_key: false,
    )
  end
end
