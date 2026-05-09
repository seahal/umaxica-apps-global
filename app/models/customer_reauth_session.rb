# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: customer_reauth_sessions
# Database name: symbol
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
#  customer_id   :bigint           not null
#
# Indexes
#
#  index_customer_reauth_sessions_on_customer_id_and_status  (customer_id,status)
#
class CustomerReauthSession < SymbolRecord
  include Retainable

  STATUSES = %w(PENDING VERIFIED CANCELLED EXPIRED).freeze
  METHODS = %w(passkey totp email_otp).freeze

  belongs_to :customer

  validates :scope, presence: true
  validates :return_to, presence: true
  validates :method, presence: true, inclusion: { in: METHODS }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :lapses_at, presence: true
  validates :attempt_count, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :for_customer, ->(customer) { where(customer_id: customer.id) }
  scope :recent_first, -> { order(created_at: :desc) }
  scope :pending, -> { where(status: "PENDING") }

  def expired?
    lapses_at <= Time.current
  end
end
