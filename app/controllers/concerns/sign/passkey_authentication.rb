# typed: false
# frozen_string_literal: true

module Sign
  module PasskeyAuthentication
    extend ActiveSupport::Concern

    private

    def build_authentication_credential
      WebAuthn::Credential.from_get(credential_params.to_h, relying_party: webauthn_relying_party)
    rescue StandardError => e
      Rails.logger.warn("WebAuthn: Invalid credential payload (#{e.class})")
      render_error("errors.webauthn.credential_not_found", :unauthorized)
      nil
    end

    def verify_authentication_credential!(credential:, passkey:, challenge:)
      credential.verify(
        challenge,
        public_key: passkey.public_key,
        sign_count: passkey.sign_count,
      )

      attrs = { sign_count: credential.sign_count }
      attrs[:last_used_at] = Time.current if passkey.has_attribute?(:last_used_at)
      passkey.update!(attrs)
    end
  end
end
