# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: member_notifications
# Database name: app_signal
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
#  fk_rails_...  (user_notification_id => client_notification_records.id) ON DELETE => cascade
#

class MemberNotification < AppSignalRecord
  include ::PublicId

  belongs_to :client_notification_record,
             class_name: "ClientNotificationRecord",
             foreign_key: :user_notification_id,
             optional: false,
             inverse_of: :member_notifications
end
