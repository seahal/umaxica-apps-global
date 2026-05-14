# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_token_statuses
# Database name: mark
#
#  id :bigint           not null, primary key
#

class UserTokenStatus < MarkRecord
  include ReferenceRecord

  NOTHING = 0
  ACTIVE = 1
  EXPIRED = 102
  RESTRICTED = 103
  REVOKED = 104
  DEFAULTS = [NOTHING, ACTIVE, EXPIRED, RESTRICTED, REVOKED].freeze

  has_many :user_tokens, dependent: :restrict_with_error
end
