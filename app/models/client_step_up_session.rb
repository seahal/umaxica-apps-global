# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_step_up_sessions
# Database name: app_ticket
#
#  id            :bigint           not null, primary key
#  attempt_count :integer          default(0), not null
#  discarded_at  :datetime         default(Infinity), not null
#  method        :string
#  purged_at     :datetime         default(Infinity), not null
#  return_to     :text             not null
#  scope         :string           not null
#  status        :string           not null
#  verified_at   :datetime
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_token_id :bigint           not null
#
# Indexes
#
#  index_user_step_up_sessions_on_user_token_id  (user_token_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_token_id => user_tokens.id) ON DELETE => cascade
#
class ClientStepUpSession < AppTicketRecord
  self.table_name = "user_step_up_sessions"
  include Retainable

  STATUSES = %w(PENDING VERIFIED).freeze
  METHODS = %w(passkey totp email_otp).freeze

  belongs_to :user_token, class_name: "ClientToken", inverse_of: :step_up_session

  validates :scope, presence: true
  validates :return_to, presence: true
  validates :method, inclusion: { in: METHODS }, allow_nil: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :discarded_at, presence: true
  validates :attempt_count, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :for_user_token, ->(user_token) { where(user_token_id: user_token.id) }
  scope :recent_first, -> { order(created_at: :desc) }
  scope :pending, -> { where(status: "PENDING") }

  def expired?
    discarded_at <= Time.current
  end
end
