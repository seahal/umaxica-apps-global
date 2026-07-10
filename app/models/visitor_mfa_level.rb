# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_mfa_levels
# Database name: com_principal
#
#  id :bigint           not null, primary key
#
class VisitorMfaLevel < ComPrincipalRecord
  include ReferenceRecord

  NOTHING = 0
  WEAK = 1
  MEDIUM = 5
  FULL = 9

  DEFAULTS = [NOTHING, WEAK, MEDIUM, FULL].freeze

  has_many :visitors,
           foreign_key: :mfa_level_id,
           dependent: :restrict_with_error,
           inverse_of: :mfa_level
end
