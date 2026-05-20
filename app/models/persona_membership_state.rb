# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: persona_membership_states
# Database name: app_zenith
#
#  id :bigint           not null, primary key
#
class PersonaMembershipState < AppRpRecord
  include ReferenceRecord

  NOTHING = 0
  ACTIVE = 1
  PENDING = 2
  SUSPENDED = 3
  REVOKED = 4
  ENDED = 5
  DEFAULTS = [NOTHING, ACTIVE, PENDING, SUSPENDED, REVOKED, ENDED].freeze

  has_many :persona_memberships,
           foreign_key: :membership_state_id,
           dependent: :restrict_with_error,
           inverse_of: :membership_state
end
