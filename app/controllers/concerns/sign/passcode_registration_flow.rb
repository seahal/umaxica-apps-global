# typed: false
# frozen_string_literal: true

module Sign
  module PasscodeRegistrationFlow
    extend ActiveSupport::Concern

    private

    def prepare_passcode_registration
      @secret = passcode_registration_secrets.new
      @raw_secret = passcode_registration_secret_class.generate_raw_secret
      session[passcode_registration_raw_session_key] = @raw_secret
      @secret.name = @raw_secret.first(4)
    end

    def create_passcode_registration!
      raw_secret = session.delete(passcode_registration_raw_session_key)
      raw_secret = passcode_registration_secret_class.generate_raw_secret if raw_secret.blank?

      passcode_registration_create_secret!(raw_secret)
    end

    def passcode_registration_secret_params
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
