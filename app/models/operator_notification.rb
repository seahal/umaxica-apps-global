# typed: false
# frozen_string_literal: true

# rubocop:disable Layout/LineLength

# == Schema Information
#
# Table name: operator_notifications
# Database name: notification
#
#  id                    :bigint           not null, primary key
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  public_id             :string           default(""), not null
#  staff_notification_id :bigint           not null
#
# Indexes
#
#  index_operator_notifications_on_public_id              (public_id) UNIQUE
#  index_operator_notifications_on_staff_notification_id  (staff_notification_id)
#
# Foreign Keys
#
#  fk_rails_...  (staff_notification_id => staff_notifications.id) ON DELETE => cascade
#

class OperatorNotification < NotificationRecord
  include ::PublicId

  belongs_to :staff_notification, optional: false, inverse_of: :operator_notifications
end
# rubocop:enable Layout/LineLength
