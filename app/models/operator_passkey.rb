# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: operator_passkeys
# Database name: org_zenith
#
#  id                       :bigint           not null, primary key
#  aaguid                   :uuid
#  authenticator_attachment :string
#  backup_eligible          :boolean
#  backup_state             :boolean
#  description              :string           default(""), not null
#  last_used_at             :datetime
#  metadata_source          :string
#  provider_name            :string
#  public_key               :text             not null
#  sign_count               :bigint           default(0), not null
#  transports               :jsonb
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  external_id              :uuid             not null
#  staff_id                 :bigint           not null
#  status_id                :bigint           default(1), not null
#  webauthn_id              :string           default(""), not null
#
# Indexes
#
#  index_operator_passkeys_on_external_id  (external_id)
#  index_operator_passkeys_on_staff_id     (staff_id)
#  index_operator_passkeys_on_status_id    (status_id)
#  index_operator_passkeys_on_webauthn_id  (webauthn_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (staff_id => operators.id)
#  fk_rails_...  (status_id => operator_passkey_statuses.id)
#

class OperatorPasskey < OrgPrincipalRecord
  include MfaStatusCredential

  MAX_PASSKEYS_PER_STAFF = 4
  attribute :status_id, default: OperatorPasskeyStatus::ACTIVE

  belongs_to :staff, inverse_of: :staff_passkeys, class_name: "Operator"
  mfa_status_owner :staff
  belongs_to :status, class_name: "OperatorPasskeyStatus"

  scope :active, -> { where(status_id: OperatorPasskeyStatus::ACTIVE) }

  validates :webauthn_id, presence: true, uniqueness: true
  validates :external_id, presence: true
  validates :public_key, presence: true
  validates :description, presence: true
  validates :status_id, numericality: { only_integer: true }
  validates :sign_count, presence: true, numericality: { greater_than_or_equal_to: 0 }

  validates_with AssociatedRecordLimitValidator,
                 on: :create,
                 owner: :staff,
                 association: :staff_passkeys,
                 foreign_key: :staff_id,
                 limit: :MAX_PASSKEYS_PER_STAFF,
                 record_name: "passkeys",
                 owner_name: "staff"

  before_validation :set_defaults, on: :create

  private

  def set_defaults
    self.external_id ||= SecureRandom.uuid
    self.sign_count ||= 0
    self.description = I18n.t("sign.default_passkey_description") if description.blank?
  end
end
