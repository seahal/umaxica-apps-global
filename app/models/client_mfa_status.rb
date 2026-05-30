# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_mfa_statuses
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
class ClientMfaStatus < AppPrincipalRecord
  include ReferenceRecord

  NOTHING = 0
  ACTIVE = 1
  UNCONFIGURED = 5
  DEFAULTS = [NOTHING, ACTIVE, UNCONFIGURED].freeze

  has_many :users, class_name: "Client",
                   foreign_key: :mfa_status_id,
                   dependent: :restrict_with_error,
                   inverse_of: :mfa_status
end
