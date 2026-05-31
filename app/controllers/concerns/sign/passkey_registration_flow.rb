# typed: false
# frozen_string_literal: true

module Sign
  module PasskeyRegistrationFlow
    extend ActiveSupport::Concern

    private

    def render_passkey_registration_options
      challenge_id, creation_options = create_registration_challenge(
        resource: passkey_registration_actor,
        exclude_credentials: passkey_registration_existing_credentials,
      )

      render json: {
        challenge_id: challenge_id,
        options: creation_options,
      }, status: :ok
    rescue Sign::Webauthn::OriginValidationError => e
      Rails.logger.error(
        Jit::LogEvent.format(
          "sign.webauthn.registration.origin_validation_failed", message: e.message,
                                                                 exception: e,
        ),
      )
      render json: { error: I18n.t("errors.webauthn.origin_invalid") }, status: :forbidden
    rescue Sign::Webauthn::ChallengeError, WebAuthn::Error, ArgumentError => e
      Rails.logger.error(
        Jit::LogEvent.format(
          "sign.webauthn.registration.options_failed", error_class: e.class.name,
                                                       message: e.message,
        ),
      )
      render json: { error: I18n.t("errors.webauthn.options_failed") }, status: :unprocessable_content
    end

    def verify_and_create_passkey_registration!
      challenge_id = params[:challenge_id]
      return render_passkey_registration_missing_challenge_id if challenge_id.blank?

      with_challenge(challenge_id, purpose: :registration) do |challenge|
        credential = WebAuthn::Credential.from_create(
          passkey_registration_credential_params.to_h,
          relying_party: webauthn_relying_party,
        )
        credential.verify(challenge)

        passkey = passkey_registration_passkeys.new(
          webauthn_id: credential.id,
          public_key: credential.public_key,
          sign_count: credential.sign_count,
          description: passkey_registration_description,
        )
        save_passkey_registration!(passkey)
        passkey
      end
    rescue Sign::Webauthn::ChallengeNotFoundError,
           Sign::Webauthn::ChallengeExpiredError,
           Sign::Webauthn::ChallengePurposeMismatchError => e
      Rails.logger.warn(Jit::LogEvent.format("sign.webauthn.registration.challenge_error", message: e.message))
      render json: { error: I18n.t("errors.webauthn.challenge_invalid") }, status: :bad_request
      nil
    rescue WebAuthn::Error => e
      Rails.logger.warn(Jit::LogEvent.format("sign.webauthn.registration.failed", message: e.message))
      render json: { error: I18n.t("errors.webauthn.verification_failed") }, status: :unprocessable_content
      nil
    rescue ActiveRecord::RecordNotUnique
      render json: { error: I18n.t("errors.webauthn.credential_already_registered") }, status: :conflict
      nil
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn(Jit::LogEvent.format("sign.webauthn.registration.persist_failed", message: e.message))
      render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_content
      nil
    end

    def passkey_registration_existing_credentials
      passkey_registration_passkeys.map { |passkey| { id: passkey.webauthn_id } }
    end

    def passkey_registration_credential_params
      params.fetch(:credential, {}).permit(
        :id,
        :rawId,
        :type,
        :authenticatorAttachment,
        { transports: [] },
        { response: %i(clientDataJSON attestationObject) },
        { clientExtensionResults: {} },
      )
    end

    def passkey_registration_description
      params[:description].presence || I18n.t("sign.default_passkey_description")
    end

    def save_passkey_registration!(passkey)
      passkey.save!
    end

    def render_passkey_registration_missing_challenge_id
      render json: {
        error: I18n.t("errors.webauthn.challenge_id_required"),
      }, status: :bad_request
      nil
    end
  end
end
