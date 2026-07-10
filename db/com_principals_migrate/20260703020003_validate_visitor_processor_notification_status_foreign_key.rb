# frozen_string_literal: true

class ValidateVisitorProcessorNotificationStatusForeignKey < ActiveRecord::Migration[8.2]
  def change
    validate_foreign_key(
      :visitor_processor_erasure_notifications,
      :visitor_processor_erasure_notification_statuses,
    )
  end
end
