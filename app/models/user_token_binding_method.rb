# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_token_binding_methods
# Database name: mark
#
#  id :bigint           not null, primary key
#
class UserTokenBindingMethod < MarkRecord
  NOTHING = 0
  DBSC = 1
  LEGACY = 2
  DEFAULTS = [NOTHING, DBSC, LEGACY].freeze

  has_many :user_tokens, dependent: :restrict_with_error

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
