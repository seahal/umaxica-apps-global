# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: staff_token_binding_methods
# Database name: token
#
#  id :bigint           not null, primary key
#
class StaffTokenBindingMethod < TokenRecord
  NOTHING = 0
  DBSC = 1
  LEGACY = 2
  DEFAULTS = [NOTHING, DBSC, LEGACY].freeze

  has_many :staff_tokens, dependent: :restrict_with_error

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
