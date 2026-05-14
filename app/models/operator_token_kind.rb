# typed: false
# == Schema Information
#
# Table name: staff_token_kinds
# Database name: token
#
#  id :bigint           not null, primary key
#
# frozen_string_literal: true

class OperatorTokenKind < TokenRecord
  self.table_name = "staff_token_kinds"
  include ReferenceRecord

  self.record_timestamps = false

  BROWSER_WEB = 1
  CLIENT_IOS = 2
  CLIENT_ANDROID = 3

  DEFAULTS = [BROWSER_WEB, CLIENT_IOS, CLIENT_ANDROID].freeze

  has_many :staff_tokens, class_name: "OperatorToken", dependent: :restrict_with_error
end
