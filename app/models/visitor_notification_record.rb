# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_notification_records
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
#  index_visitor_notification_records_on_public_id   (public_id) UNIQUE
#  index_visitor_notification_records_on_visitor_id  (visitor_id)
#
class VisitorNotificationRecord < ComSignalRecord
  include NotificationOwnerRecord

  belongs_to :visitor, inverse_of: :notification_records
end
