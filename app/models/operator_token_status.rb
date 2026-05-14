# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_token_statuses
# Database name: token
#
#  id :bigint           not null, primary key
#

class OperatorTokenStatus < TokenRecord
  self.table_name = "staff_token_statuses"
  include ReferenceRecord

  NOTHING = 0
  ACTIVE = 1
  EXPIRED = 102
  RESTRICTED = 103
  REVOKED = 104
  DEFAULTS = [NOTHING, ACTIVE, EXPIRED, RESTRICTED, REVOKED].freeze

  has_many :staff_tokens, class_name: "OperatorToken", dependent: :restrict_with_error
end
