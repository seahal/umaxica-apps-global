# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_sign_out_cycle_kinds
# Database name: com_ticket
#
#  id :bigint           not null, primary key
#
class VisitorSignOutCycleKind < ComTicketRecord
  include ReferenceRecord

  NOTHING = 0
  IDP_SIGN_OUT = 10
  RP_INITIATED = 20
  SESSION_REVOKE = 30
  DEFAULTS = [NOTHING, IDP_SIGN_OUT, RP_INITIATED, SESSION_REVOKE].freeze

  has_many :visitor_sign_out_cycles,
           foreign_key: :kind_id,
           dependent: :restrict_with_error,
           inverse_of: :kind
end
