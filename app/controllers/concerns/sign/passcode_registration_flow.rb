# typed: false
# frozen_string_literal: true

module Sign
  module PasscodeRegistrationFlow
    extend ActiveSupport::Concern

    private

    def prepare_passcode_registration
      @secret_credential = passcode_registration_secret_credentials.new
      @raw_secret_credential = passcode_registration_secret_credential_class.generate_raw_secret_credential
      session[passcode_registration_raw_session_key] = @raw_secret_credential
      @secret_credential.name = @raw_secret_credential.first(4)
    end

    def create_passcode_registration!
      raw_secret_credential = session.delete(passcode_registration_raw_session_key)
      if raw_secret_credential.blank?
        raw_secret_credential = passcode_registration_secret_credential_class.generate_raw_secret_credential
      end

      passcode_registration_create_secret_credential!(raw_secret_credential)
    end

    def passcode_registration_secret_credential_params
      params.fetch(
        passcode_registration_param_key,
        params.fetch(passcode_registration_fallback_param_key, {}),
      ).permit(:name, :enabled)
    end

    def passcode_registration_fallback_param_key
      passcode_registration_param_key
    end
  end
end
