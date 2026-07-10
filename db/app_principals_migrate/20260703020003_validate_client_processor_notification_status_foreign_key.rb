# frozen_string_literal: true

class ValidateClientProcessorNotificationStatusForeignKey < ActiveRecord::Migration[8.2]
  def change
    validate_foreign_key(
      :client_processor_erasure_notifications,
      :client_processor_erasure_notification_statuses,
    )
  end
end
