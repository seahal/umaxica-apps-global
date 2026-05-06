# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_reauth_sessions
# Database name: token
#
#  id            :bigint           not null, primary key
#  attempt_count :integer          default(0), not null
#  expires_at    :datetime         not null
#  method        :string           not null
#  return_to     :text             not null
#  scope         :string           not null
#  status        :string           not null
#  verified_at   :datetime
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  staff_id      :bigint           not null
#
# Indexes
#
#  index_staff_reauth_sessions_on_expires_at           (expires_at)
#  index_staff_reauth_sessions_on_staff_id_and_status  (staff_id,status)
#
class StaffReauthSession < TokenRecord
  STATUSES = %w(PENDING VERIFIED CANCELLED EXPIRED).freeze
  METHODS = %w(passkey totp email_otp).freeze

  belongs_to :staff

  validates :scope, presence: true
  validates :return_to, presence: true
  validates :method, presence: true, inclusion: { in: METHODS }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :expires_at, presence: true
  validates :attempt_count, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :for_staff, ->(staff) { where(staff_id: staff.id) }
  scope :recent_first, -> { order(created_at: :desc) }
  scope :pending, -> { where(status: "PENDING") }

  def expired?
    expires_at <= Time.current
  end
end
