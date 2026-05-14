# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_notifications
# Database name: notification
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

class OperatorNotificationTest < ActiveSupport::TestCase
  test "class is defined" do
    assert_equal "OperatorNotification", OperatorNotification.name
  end
end
