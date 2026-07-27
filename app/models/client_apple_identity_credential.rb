# typed: false
# frozen_string_literal: true

class ClientAppleIdentityCredential < AppPrincipalRecord
  STATES = %w(active revoked consent_revoked account_deleted).freeze

  encrypts :refresh_token

  belongs_to :client_external_identity, inverse_of: :client_apple_identity_credential

  validates :state, inclusion: { in: STATES }
  validate :external_identity_is_apple

  def active?
    state == "active"
  end

  private

  def external_identity_is_apple
    return if client_external_identity&.provider == "apple"

    errors.add(:client_external_identity, :invalid)
  end
end
