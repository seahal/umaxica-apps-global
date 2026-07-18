# typed: false
# frozen_string_literal: true

module Webauthn
  # Creates authentication options and verifies assertions for one surface's
  # relying party against a stored credential.
  #
  # Server-side guarantees, independent of what the client requested:
  # - the signature verifies against the stored public key (gem)
  # - RP ID hash, clientData type, and origin match the surface config (gem)
  # - the assertion is user-present AND user-verified — UV=false is rejected,
  #   so a successful verification always supports the AAL2-aligned claim
  # - a sign-count regression (cloned-authenticator signal) is rejected by the
  #   gem via WebAuthn::SignCountVerificationError
  class AssertionVerifier
    class VerificationError < StandardError; end

    class UserVerificationRequiredError < VerificationError; end

    class UserPresenceRequiredError < VerificationError; end

    USER_VERIFICATION = "required"

    def self.options_for(config:, allow_ids:)
      config.relying_party.options_for_authentication(
        allow: allow_ids,
        user_verification: USER_VERIFICATION,
      )
    end

    def self.verify!(credential_params:, challenge:, config:, public_key:, sign_count:)
      credential = WebAuthn::Credential.from_get(credential_params, relying_party: config.relying_party)
      credential.verify(
        challenge,
        public_key: public_key,
        sign_count: sign_count,
        user_verification: true,
      )

      authenticator_data = credential.response.authenticator_data
      raise UserVerificationRequiredError, "assertion is not user-verified" unless authenticator_data.user_verified?
      raise UserPresenceRequiredError, "assertion is not user-present" unless authenticator_data.user_present?

      AuthenticationContext.from_credential(credential)
    end
  end
end
