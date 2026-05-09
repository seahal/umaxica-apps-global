# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: customer_token_statuses
# Database name: symbol
#
#  id :bigint           not null, primary key
#
class CustomerTokenStatus < SymbolRecord
  include ReferenceRecord

  NOTHING = 0
  ACTIVE = 1
  EXPIRED = 2

  has_many :customer_tokens, dependent: :restrict_with_error
end
