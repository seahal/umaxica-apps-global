# frozen_string_literal: true

class AddClientProcessorNotificationStatusForeignKey < ActiveRecord::Migration[8.2]
  def change
    add_foreign_key(
      :client_processor_erasure_notifications,
      :client_processor_erasure_notification_statuses,
      column: :status_id,
      validate: false,
    )
  end
end
