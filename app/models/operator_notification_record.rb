# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_notification_records
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
#  index_operator_notification_records_on_public_id  (public_id) UNIQUE
#  index_operator_notification_records_on_staff_id   (staff_id)
#
class OperatorNotificationRecord < OrgSignalRecord
  include NotificationOwnerRecord

  belongs_to :operator, class_name: "Operator", foreign_key: :staff_id, inverse_of: :notification_records
  has_many :operator_notifications,
           foreign_key: :staff_notification_id,
           inverse_of: :operator_notification_record,
           dependent: :delete_all
end
