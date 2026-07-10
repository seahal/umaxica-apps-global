# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_identity_states
# Database name: org_zenith
#
#  id :bigint           not null, primary key
#
class OperatorIdentityState < OrgRpRecord
  include ReferenceRecord

  NOTHING = 0
  ACTIVE = 1
  SUSPENDED = 2
  DELETED = 3
  DEFAULTS = [NOTHING, ACTIVE, SUSPENDED, DELETED].freeze

  has_many :operator_identities, class_name: "OperatorIdentity", foreign_key: :status_id,
                                 dependent: :restrict_with_error,
                                 inverse_of: :identity_state
end
