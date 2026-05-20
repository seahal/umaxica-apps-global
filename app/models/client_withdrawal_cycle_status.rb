# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_withdrawal_cycle_statuses
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
class ClientWithdrawalCycleStatus < AppPrincipalRecord
  include ReferenceRecord

  NOTHING = 0
  REQUESTED = 10
  CLOSING = 20
  DISCARDED = 30
  RECOVERED = 40
  TERMINATED = 100
  FAILED = 900
  DEFAULTS = [NOTHING, REQUESTED, CLOSING, DISCARDED, RECOVERED, TERMINATED, FAILED].freeze

  has_many :client_withdrawal_cycles,
           foreign_key: :status_id,
           dependent: :restrict_with_error,
           inverse_of: :status
end
