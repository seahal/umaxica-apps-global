# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_token_dbsc_statuses
# Database name: token
#
#  id :bigint           not null, primary key
#
class OperatorTokenDbscStatus < TokenRecord
  self.table_name = "staff_token_dbsc_statuses"
  include ReferenceRecord

  NOTHING = 0
  ACTIVE = 1
  PENDING = 2
  FAILED = 3
  REVOKE = 4
  DEFAULTS = [NOTHING, ACTIVE, PENDING, FAILED, REVOKE].freeze

  has_many :staff_tokens,
           class_name: "OperatorToken",
           foreign_key: :staff_token_dbsc_status_id,
           dependent: :restrict_with_error,
           inverse_of: :staff_token_dbsc_status

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
