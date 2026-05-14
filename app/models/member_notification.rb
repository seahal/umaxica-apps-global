# typed: false
# frozen_string_literal: true

# rubocop:disable Layout/LineLength

# == Schema Information
#
# Table name: member_notifications
# Database name: notification
#
#  id                   :bigint           not null, primary key
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  public_id            :string           default(""), not null
#  user_notification_id :bigint           not null
#
# Indexes
#
#  index_member_notifications_on_public_id             (public_id) UNIQUE
#  index_member_notifications_on_user_notification_id  (user_notification_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_notification_id => user_notifications.id) ON DELETE => cascade
#

class MemberNotification < NotificationRecord
  include ::PublicId

  belongs_to :user_notification, optional: false, inverse_of: :member_notifications
end

# rubocop:enable Layout/LineLength
