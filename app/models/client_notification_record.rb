# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_notifications
# Database name: app_signal
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  public_id  :string           default(""), not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_user_notifications_on_public_id  (public_id) UNIQUE
#  index_user_notifications_on_user_id    (user_id)
#

class ClientNotificationRecord < AppSignalRecord
  self.table_name = "user_notifications"
  include NotificationOwnerRecord

  belongs_to :client,
             class_name: "Client",
             foreign_key: :user_id,
             inverse_of: :notification_records
  has_many :member_notifications,
           foreign_key: :user_notification_id,
           inverse_of: :client_notification_record,
           dependent: :delete_all
end
