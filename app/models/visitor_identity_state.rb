# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: visitor_identity_states
# Database name: com_zenith
#
#  id :bigint           not null, primary key
#
class VisitorIdentityState < ComRpRecord
  include ReferenceRecord

  NOTHING = 0
  ACTIVE = 1
  SUSPENDED = 2
  DELETED = 3
  DEFAULTS = [NOTHING, ACTIVE, SUSPENDED, DELETED].freeze

  has_many :visitor_identities,
           class_name: "VisitorIdentity",
           foreign_key: :status_id,
           dependent: :restrict_with_error,
           inverse_of: :identity_state
end
