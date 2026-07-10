# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_email_statuses
# Database name: app_principal
#
#  id :bigint           not null, primary key
#
class ClientEmailStatus < AppPrincipalRecord
  include ReferenceRecord

  UNVERIFIED = 1
  VERIFIED = 2
  SUSPENDED = 3
  DELETED = 4
  NOTHING = 5
  UNVERIFIED_WITH_SIGN_UP = 6
  VERIFIED_WITH_SIGN_UP = 7
  DEFAULTS = [UNVERIFIED, VERIFIED, SUSPENDED, DELETED, NOTHING, UNVERIFIED_WITH_SIGN_UP,
              VERIFIED_WITH_SIGN_UP,].freeze

  has_many :client_emails, inverse_of: :user_email_status, dependent: :restrict_with_error

  def self.ensure_defaults!
    insert_missing_fixed_ids!(DEFAULTS)
  end
end
