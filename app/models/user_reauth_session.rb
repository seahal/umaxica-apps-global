# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_reauth_sessions
# Database name: mark
#
#  id            :bigint           not null, primary key
#  attempt_count :integer          default(0), not null
#  lapses_at     :datetime         default(Infinity), not null
#  method        :string           not null
#  purge_at      :datetime         default(Infinity), not null
#  return_to     :text             not null
#  scope         :string           not null
#  status        :string           not null
#  verified_at   :datetime
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_id       :bigint           not null
#
# Indexes
#
#  index_user_reauth_sessions_on_user_id_and_status  (user_id,status)
#
class UserReauthSession < MarkRecord
  include Retainable

  STATUSES = %w(PENDING VERIFIED CANCELLED EXPIRED).freeze
  METHODS = %w(passkey totp email_otp).freeze

  belongs_to :user

  validates :scope, presence: true
  validates :return_to, presence: true
  validates :method, presence: true, inclusion: { in: METHODS }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :lapses_at, presence: true
  validates :attempt_count, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :for_user, ->(user) { where(user_id: user.id) }
  scope :recent_first, -> { order(created_at: :desc) }
  scope :pending, -> { where(status: "PENDING") }

  def expired?
    lapses_at <= Time.current
  end
end
