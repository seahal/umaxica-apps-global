# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_token_statuses
# Database name: com_ticket
#
#  id :bigint           not null, primary key
#
class VisitorTokenStatus < ComTicketRecord
  include ReferenceRecord

  NOTHING = 0
  ACTIVE = 1
  EXPIRED = 102
  RESTRICTED = 103
  REVOKED = 104
  DEFAULTS = [NOTHING, ACTIVE, EXPIRED, RESTRICTED, REVOKED].freeze

  has_many :visitor_tokens, dependent: :restrict_with_error
end
