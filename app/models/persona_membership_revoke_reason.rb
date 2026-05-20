# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: persona_membership_revoke_reasons
# Database name: app_zenith
#
#  id :bigint           not null, primary key
#
class PersonaMembershipRevokeReason < AppRpRecord
  include ReferenceRecord

  NOTHING = 0
  MANUAL = 1
  EXPIRED = 2
  POLICY = 3
  DEFAULTS = [NOTHING, MANUAL, EXPIRED, POLICY].freeze

  has_many :persona_memberships,
           foreign_key: :revoke_reason_id,
           dependent: :restrict_with_error,
           inverse_of: :revoke_reason
end
