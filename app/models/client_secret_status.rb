# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_secret_statuses
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
class ClientSecretStatus < AppPrincipalRecord
  include ReferenceRecord

  ACTIVE = 1
  EXPIRED = 2
  REVOKED = 3
  USED = 4
  DELETED = 5
  NOTHING = 6
  DEFAULTS = [ACTIVE, EXPIRED, REVOKED, USED, DELETED, NOTHING].freeze
  has_many :client_secrets, inverse_of: :user_secret_status, dependent: :restrict_with_error
end
