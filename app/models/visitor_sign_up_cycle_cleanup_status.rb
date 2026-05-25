# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_sign_up_cycle_cleanup_statuses
# Database name: com_ticket
#
#  id :bigint           not null, primary key
#
class VisitorSignUpCycleCleanupStatus < ComTicketRecord
  include ReferenceRecord

  NOTHING = 0
  IDLE = 10
  PENDING = 20
  COMPLETED = 30
  FAILED = 40
  DEFAULTS = [NOTHING, IDLE, PENDING, COMPLETED, FAILED].freeze

  ACTIVE = [PENDING, FAILED].freeze

  has_many :visitor_sign_up_cycles,
           foreign_key: :cleanup_status_id,
           dependent: :restrict_with_error,
           inverse_of: :cleanup_status
end
