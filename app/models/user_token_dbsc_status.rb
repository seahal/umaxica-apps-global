# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_token_dbsc_statuses
# Database name: mark
#
#  id :bigint           not null, primary key
#
class UserTokenDbscStatus < MarkRecord
  include ReferenceRecord

  # Fixed IDs - do not modify these values
  NOTHING = 0
  ACTIVE = 1
  PENDING = 2
  FAILED = 3
  REVOKE = 4
  DEFAULTS = [NOTHING, ACTIVE, PENDING, FAILED, REVOKE].freeze

  has_many :user_tokens, dependent: :restrict_with_error

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
