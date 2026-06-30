# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: organization_entra_connections
# Database name: org_zenith
#
#  id                  :bigint           not null, primary key
#  public_id           :string(21)       not null
#  organization_id     :bigint           not null
#  entra_tenant_id     :string(36)       not null
#  entra_client_id     :string(255)      not null
#  entra_client_secret :text             not null (encrypted at rest)
#  status_id           :bigint           not null, default: 0
#  last_used_at        :datetime
#  revoked_at          :datetime
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_organization_entra_connections_on_public_id           (public_id) UNIQUE
#  idx_org_entra_connections_on_org_and_tenant                 (organization_id, entra_tenant_id) UNIQUE
#  idx_org_entra_connections_on_tenant_and_client              (entra_tenant_id, entra_client_id) UNIQUE
#  index_organization_entra_connections_on_status_id           (status_id)
#
# Foreign Keys
#
#  fk_rails_...  (status_id => organization_entra_connection_states.id)
#
# organization_id is a logical reference to organizations in org_principal (cross-DB; no enforced FK).
# See adr/org-entra-id-sign-in-boundary.md.
class OrganizationEntraConnection < OrgRpRecord
  include ::PublicId

  encrypts :entra_client_secret

  ENTRA_TENANT_ID_FORMAT = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
  private_constant :ENTRA_TENANT_ID_FORMAT

  belongs_to :connection_state,
             class_name: "OrganizationEntraConnectionState",
             foreign_key: :status_id,
             inverse_of: :organization_entra_connections

  has_many :operator_entra_identities,
           foreign_key: :connection_id,
           inverse_of: :connection,
           dependent: :restrict_with_error

  validates :organization_id, :entra_tenant_id, :entra_client_id, :entra_client_secret,
            presence: true
  validates :entra_tenant_id, uniqueness: { scope: :organization_id }
  validates :entra_client_id, uniqueness: { scope: :entra_tenant_id }
  validates :entra_tenant_id, format: { with: ENTRA_TENANT_ID_FORMAT, message: "must be a valid UUID" }
end
