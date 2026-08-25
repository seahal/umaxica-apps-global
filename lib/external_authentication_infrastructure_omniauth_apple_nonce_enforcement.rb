# typed: false
# frozen_string_literal: true

module ExternalAuthenticationInfrastructureOmniauthAppleNonceEnforcement
  private

  # omniauth-apple 1.4.0 verifies nonce only when the ID token asserts
  # nonce_supported. This application always sends nonce, so its absence must
  # fail authentication even when that nonstandard claim is absent.
  def verify_claims!(id_token)
    super
    verify_nonce!(id_token) unless id_token[:nonce_supported]
  end
end
