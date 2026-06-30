# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: organization_entra_connection_states
# Database name: org_zenith
#
#  id :bigint           not null, primary key
#
class OrganizationEntraConnectionState < OrgRpRecord
  include ReferenceRecord

  NOTHING   = 0
  ACTIVE    = 1
  SUSPENDED = 2
  REVOKED   = 3
  DEFAULTS  = [NOTHING, ACTIVE, SUSPENDED, REVOKED].freeze

  has_many :organization_entra_connections,
           foreign_key: :status_id,
           dependent: :restrict_with_error,
           inverse_of: :connection_state
end
