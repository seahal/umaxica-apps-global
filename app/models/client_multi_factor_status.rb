# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_multi_factor_statuses
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
class ClientMultiFactorStatus < AppPrincipalRecord
  self.table_name = "user_multi_factor_statuses"
  include ReferenceRecord

  NOTHING = 0
  ACTIVE = 1
  UNCONFIGURED = 5
  DEFAULTS = [NOTHING, ACTIVE, UNCONFIGURED].freeze

  has_many :users, class_name: "Client",
                   foreign_key: :multi_factor_status_id,
                   dependent: :restrict_with_error,
                   inverse_of: :multi_factor_status
end
