# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_reauth_sessions
# Database name: token
#
#  id             :bigint           not null, primary key
#  attempt_count  :integer          default(0), not null
#  lapses_at      :datetime         default(Infinity), not null
#  method         :string
#  purge_at       :datetime         default(Infinity), not null
#  return_to      :text             not null
#  scope          :string           not null
#  status         :string           not null
#  verified_at    :datetime
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  staff_token_id :bigint           not null
#
# Indexes
#
#  index_staff_reauth_sessions_on_staff_token_id  (staff_token_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (staff_token_id => staff_tokens.id) ON DELETE => cascade
#
class OperatorReauthSession < TokenRecord
  self.table_name = "staff_reauth_sessions"
  include Retainable

  STATUSES = %w(PENDING VERIFIED).freeze
  METHODS = %w(passkey email_otp).freeze

  belongs_to :staff_token, class_name: "OperatorToken", inverse_of: :reauth_session

  validates :scope, presence: true
  validates :return_to, presence: true
  validates :method, inclusion: { in: METHODS }, allow_nil: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :lapses_at, presence: true
  validates :attempt_count, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :for_staff_token, ->(staff_token) { where(staff_token_id: staff_token.id) }
  scope :recent_first, -> { order(created_at: :desc) }
  scope :pending, -> { where(status: "PENDING") }

  def expired?
    lapses_at <= Time.current
  end
end
