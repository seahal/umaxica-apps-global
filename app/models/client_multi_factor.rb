# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_multi_factors
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
class ClientMultiFactor < AppPrincipalRecord
  self.table_name = "user_multi_factors"
  include ReferenceRecord

  NOTHING = 0
  WEAK = 1
  MEDIUM = 5
  FULL = 9

  DEFAULTS = [NOTHING, WEAK, MEDIUM, FULL].freeze

  has_many :users, class_name: "Client",
                   foreign_key: :multi_factor_id,
                   dependent: :restrict_with_error,
                   inverse_of: :multi_factor
end
