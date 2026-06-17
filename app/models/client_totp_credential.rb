# typed: false
# frozen_string_literal: true

# frozen_string_literal: true

# == Schema Information
#
# Table name: client_totp_credentials
# Database name: app_principal
#
#  id                                      :bigint           not null, primary key
#  last_otp_at                             :datetime         default(-Infinity), not null
#  private_key                             :string(1024)     default(""), not null
#  title                                   :string(32)
#  created_at                              :datetime         not null
#  updated_at                              :datetime         not null
#  public_id                               :string(21)       not null
#  user_id                                 :bigint           not null
#  user_identity_totp_credential_status_id :bigint           default(5), not null
#
# Indexes
#
#  idx_on_user_identity_totp_credential_status_id_47a8d28ad3  (user_identity_totp_credential_status_id)
#  index_client_totp_credentials_on_public_id                 (public_id) UNIQUE
#  index_client_totp_credentials_on_user_id                   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => clients.id)
#  fk_rails_...  (user_identity_totp_credential_status_id => client_totp_credential_statuses.id)
#

class ClientTotpCredential < AppPrincipalRecord
  include ::PublicId
  include MfaStatusCredential

  encrypts :private_key

  alias_attribute :user_totp_credential_status_id, :user_identity_totp_credential_status_id
  MAX_TOTPS_PER_USER = 2

  attr_accessor :first_token

  belongs_to :user, class_name: "Client", inverse_of: :client_totp_credentials
  mfa_status_owner :user
  belongs_to :user_totp_credential_status,
             class_name: "ClientTotpCredentialStatus",
             inverse_of: :client_totp_credentials,
             foreign_key: :user_identity_totp_credential_status_id
  attribute :user_identity_totp_credential_status_id, default: ClientTotpCredentialStatus::NOTHING

  validates :private_key, presence: true, length: { maximum: 1024 }
  validates :last_otp_at, presence: true
  validates :title, length: { maximum: 32 }, allow_blank: true
  validates_with AssociatedRecordLimitValidator,
                 on: :create,
                 owner: :user,
                 association: :client_totp_credentials,
                 foreign_key: :user_id,
                 limit: :MAX_TOTPS_PER_USER,
                 record_name: "totps",
                 owner_name: "user"

  after_initialize :generate_private_key_if_blank
  after_initialize :generate_public_id_if_blank

  private

  def generate_public_id_if_blank
    return unless has_attribute?(:public_id)

    self.public_id = Nanoid.generate(size: 21) if self[:public_id].blank?
  end

  def generate_private_key_if_blank
    self.private_key = ROTP::Base32.random_base32 if private_key.blank?
  end
end
