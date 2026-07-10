# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: individual_membership_states
# Database name: com_zenith
#
#  id :bigint           not null, primary key
#
class IndividualMembershipState < ComRpRecord
  include ReferenceRecord

  NOTHING = 0
  ACTIVE = 1
  PENDING = 2
  SUSPENDED = 3
  REVOKED = 4
  ENDED = 5
  DEFAULTS = [NOTHING, ACTIVE, PENDING, SUSPENDED, REVOKED, ENDED].freeze

  has_many :individual_memberships,
           foreign_key: :membership_state_id,
           dependent: :restrict_with_error,
           inverse_of: :membership_state
end
