# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: customer_token_dbsc_statuses
# Database name: symbol
#
#  id :bigint           not null, primary key
#
class CustomerTokenDbscStatus < SymbolRecord
  include ReferenceRecord

  NOTHING = 0
  PENDING = 1
  ACTIVE = 2
  FAILED = 3
  REVOKE = 4
  DEFAULTS = [NOTHING, PENDING, ACTIVE, FAILED, REVOKE].freeze

  has_many :customer_tokens, dependent: :restrict_with_error

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
