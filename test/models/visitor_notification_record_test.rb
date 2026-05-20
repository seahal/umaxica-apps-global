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
require "test_helper"

class VisitorNotificationRecordTest < ActiveSupport::TestCase
  test "class is defined" do
    assert_equal "VisitorNotificationRecord", VisitorNotificationRecord.name
  end

  test "belongs to visitor" do
    visitor = Visitor.create!
    notification = VisitorNotificationRecord.create!(visitor: visitor)

    assert_equal visitor, notification.visitor
    assert_includes visitor.notification_records, notification
  end
end
