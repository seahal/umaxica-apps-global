# frozen_string_literal: true

class AddVisitorProcessorNotificationStatusForeignKey < ActiveRecord::Migration[8.2]
  def change
    add_foreign_key(
      :visitor_processor_erasure_notifications,
      :visitor_processor_erasure_notification_statuses,
      column: :status_id,
      validate: false,
    )
  end
end
