# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_google_identities
# Database name: org_principal
#
#  id                    :bigint           not null, primary key
#  last_authenticated_at :datetime
#  provider              :string           default("google_org"), not null
#  refresh_token         :string           default(""), not null
#  token                 :string           default(""), not null
#  token_expires_at      :integer          not null
#  uid                   :string           default(""), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  staff_id              :bigint           not null
#  status_id             :bigint           default(1), not null
#
# Indexes
#
#  index_operator_google_identities_on_status_id         (status_id)
#  index_operator_google_identities_on_token_expires_at  (token_expires_at)
#  index_operator_google_identities_on_uid_and_provider  (uid,provider) UNIQUE
#  index_operator_social_googles_on_staff_id_unique      (staff_id) UNIQUE WHERE (staff_id IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (staff_id => operators.id)
#  fk_rails_...  (status_id => operator_google_identity_statuses.id)
#
class OperatorGoogleIdentity < OrgPrincipalRecord
  include SocialIdentifiable

  self.filter_attributes += %w(token refresh_token uid)

  alias_attribute :expires_at, :token_expires_at
  attribute :status_id, default: OperatorGoogleIdentityStatus::ACTIVE

  belongs_to :staff, class_name: "Operator", inverse_of: :operator_google_identity
  belongs_to :operator_google_identity_status,
             class_name: "OperatorGoogleIdentityStatus",
             inverse_of: :operator_google_identities,
             foreign_key: :status_id

  validates :token, presence: true
  validates :staff_id, uniqueness: { conditions: -> { where.not(staff_id: nil) } }
  validates :uid, presence: true, uniqueness: { scope: :provider }
  validates :token_expires_at, presence: true
  validates :status_id, numericality: { only_integer: true }

  before_validation :ensure_status_defaults, on: :create

  def self.status_column
    :status_id
  end

  def self.status_class
    OperatorGoogleIdentityStatus
  end

  private

  def ensure_status_defaults
    OperatorGoogleIdentityStatus.ensure_defaults!
  end
end
