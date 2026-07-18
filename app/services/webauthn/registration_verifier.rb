# typed: false
# frozen_string_literal: true

module Webauthn
  # Creates registration options and verifies attestation responses for one
  # surface's relying party. userVerification is always "required": every
  # credential this application registers must be usable on the AAL2-aligned
  # path, and a UV=false attestation is rejected even if the authenticator
  # claims success.
  class RegistrationVerifier
    class VerificationError < StandardError; end

    class UserVerificationRequiredError < VerificationError; end

    class UserPresenceRequiredError < VerificationError; end

    USER_VERIFICATION = "required"
    RESIDENT_KEY = "discouraged"
    ATTESTATION = "none"

    def self.options_for(config:, user_id:, user_name:, exclude_ids: [])
      config.relying_party.options_for_registration(
        user: { id: user_id, name: user_name, display_name: user_name },
        exclude: exclude_ids,
        authenticator_selection: {
          resident_key: RESIDENT_KEY,
          user_verification: USER_VERIFICATION,
        },
        attestation: ATTESTATION,
      )
    end

    def self.verify!(credential_params:, challenge:, config:)
      credential = WebAuthn::Credential.from_create(credential_params, relying_party: config.relying_party)
      credential.verify(challenge, user_verification: true)

      authenticator_data = credential.response.authenticator_data
      raise UserVerificationRequiredError, "attestation is not user-verified" unless authenticator_data.user_verified?
      raise UserPresenceRequiredError, "attestation is not user-present" unless authenticator_data.user_present?

      AuthenticationContext.from_credential(credential)
    end
  end
end
