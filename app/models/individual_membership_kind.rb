# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: individual_membership_kinds
# Database name: com_zenith
#
#  id :bigint           not null, primary key
#
class IndividualMembershipKind < ComRpRecord
  include ReferenceRecord

  NOTHING = 0
  OWNER = 1
  MEMBER = 2
  GUEST = 3
  DEFAULTS = [NOTHING, OWNER, MEMBER, GUEST].freeze

  has_many :individual_memberships,
           foreign_key: :membership_kind_id,
           dependent: :restrict_with_error,
           inverse_of: :membership_kind
end
