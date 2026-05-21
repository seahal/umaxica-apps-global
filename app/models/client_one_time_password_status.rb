# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_one_time_password_statuses
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
class ClientOneTimePasswordStatus < AppPrincipalRecord
  include ReferenceRecord

  ACTIVE = 1
  INACTIVE = 2
  REVOKED = 3
  DELETED = 4
  NOTHING = 5
  DEFAULTS = [ACTIVE, INACTIVE, REVOKED, DELETED, NOTHING].freeze

  has_many :client_one_time_passwords, dependent: :restrict_with_error,
                                       inverse_of: :user_one_time_password_status
end
