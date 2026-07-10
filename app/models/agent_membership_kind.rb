# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: agent_membership_kinds
# Database name: org_zenith
#
#  id :bigint           not null, primary key
#
class AgentMembershipKind < OrgRpRecord
  include ReferenceRecord

  NOTHING = 0
  OWNER = 1
  MEMBER = 2
  GUEST = 3
  DEFAULTS = [NOTHING, OWNER, MEMBER, GUEST].freeze

  has_many :agent_memberships,
           foreign_key: :membership_kind_id,
           dependent: :restrict_with_error,
           inverse_of: :membership_kind
end
