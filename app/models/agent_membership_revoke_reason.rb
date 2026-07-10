# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: agent_membership_revoke_reasons
# Database name: org_zenith
#
#  id :bigint           not null, primary key
#
class AgentMembershipRevokeReason < OrgRpRecord
  include ReferenceRecord

  NOTHING = 0
  MANUAL = 1
  EXPIRED = 2
  POLICY = 3
  DEFAULTS = [NOTHING, MANUAL, EXPIRED, POLICY].freeze

  has_many :agent_memberships,
           foreign_key: :revoke_reason_id,
           dependent: :restrict_with_error,
           inverse_of: :revoke_reason
end
