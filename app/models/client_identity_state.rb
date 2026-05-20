# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_identity_states
# Database name: app_zenith
#
#  id :bigint           not null, primary key
#
class ClientIdentityState < AppRpRecord
  self.table_name = "client_identity_states"
  include ReferenceRecord

  NOTHING = 0
  ACTIVE = 1
  SUSPENDED = 2
  DELETED = 3
  DEFAULTS = [NOTHING, ACTIVE, SUSPENDED, DELETED].freeze

  has_many :client_identities,
           class_name: "ClientIdentity",
           foreign_key: :status_id,
           dependent: :restrict_with_error,
           inverse_of: :identity_state
end
