# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_multi_factors
# Database name: com_principal
#
#  id :bigint           not null, primary key
#
class VisitorMultiFactor < ComPrincipalRecord
  include ReferenceRecord

  NOTHING = 0
  WEAK = 1
  MEDIUM = 5
  FULL = 9

  DEFAULTS = [NOTHING, WEAK, MEDIUM, FULL].freeze

  has_many :visitors,
           foreign_key: :multi_factor_id,
           dependent: :restrict_with_error,
           inverse_of: :multi_factor
end
