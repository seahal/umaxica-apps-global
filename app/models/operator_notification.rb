# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_notifications
# Database name: org_signal
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
#  fk_rails_...  (staff_notification_id => operator_notification_records.id) ON DELETE => cascade
#

class OperatorNotification < OrgSignalRecord
  include ::PublicId

  belongs_to :operator_notification_record,
             class_name: "OperatorNotificationRecord",
             foreign_key: :staff_notification_id,
             optional: false,
             inverse_of: :operator_notifications
end
