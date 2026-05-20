# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_notifications
# Database name: com_signal
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  public_id  :string           default(""), not null
#  visitor_id :bigint           not null
#
# Indexes
#
#  index_visitor_notifications_on_public_id   (public_id) UNIQUE
#  index_visitor_notifications_on_visitor_id  (visitor_id)
#
class VisitorNotificationRecord < ComSignalRecord
  self.table_name = "visitor_notifications"

  include NotificationOwnerRecord

  belongs_to :visitor, inverse_of: :notification_records
end
