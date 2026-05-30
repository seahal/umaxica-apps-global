# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_sign_out_flow_kinds
# Database name: app_ticket
#
#  id :bigint           not null, primary key
#
class ClientSignOutFlowKind < AppTicketRecord
  include ReferenceRecord

  NOTHING = 0
  IDP_SIGN_OUT = 10
  RP_INITIATED = 20
  SESSION_REVOKE = 30
  DEFAULTS = [NOTHING, IDP_SIGN_OUT, RP_INITIATED, SESSION_REVOKE].freeze

  has_many :client_sign_out_flows,
           foreign_key: :kind_id,
           dependent: :restrict_with_error,
           inverse_of: :kind
end
