# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: customer_token_kinds
# Database name: symbol
#
#  id :bigint           not null, primary key
#
class CustomerTokenKind < SymbolRecord
  self.primary_key = :id
  self.record_timestamps = false

  BROWSER_WEB = 1
  CLIENT_IOS = 2
  CLIENT_ANDROID = 3

  has_many :customer_tokens, dependent: :restrict_with_error
end
