# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_withdrawal_cycle_statuses
# Database name: com_principal
#
#  id :bigint           not null, primary key
#
class VisitorWithdrawalCycleStatus < ComPrincipalRecord
  include ReferenceRecord

  NOTHING = 0
  REQUESTED = 10
  CLOSING = 20
  DISCARDED = 30
  RECOVERED = 40
  TERMINATED = 100
  FAILED = 900
  DEFAULTS = [NOTHING, REQUESTED, CLOSING, DISCARDED, RECOVERED, TERMINATED, FAILED].freeze

  has_many :visitor_withdrawal_cycles,
           foreign_key: :status_id,
           dependent: :restrict_with_error,
           inverse_of: :status
end
