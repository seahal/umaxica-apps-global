# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_notifications
# Database name: org_signal
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  public_id  :string           default(""), not null
#  staff_id   :bigint           not null
#
# Indexes
#
#  index_staff_notifications_on_public_id  (public_id) UNIQUE
#  index_staff_notifications_on_staff_id   (staff_id)
#

require "test_helper"

class OperatorNotificationRecordTest < ActiveSupport::TestCase
  test "class is defined" do
    assert_equal "OperatorNotificationRecord", OperatorNotificationRecord.name
  end

  test "belongs to operator through notification_records" do
    operator = Operator.create!
    notification = OperatorNotificationRecord.create!(operator: operator)

    assert_equal operator, notification.operator
    assert_includes operator.notification_records, notification
  end
end
