# typed: false
# frozen_string_literal: true

module SignSettingsPasskeyRegistrationEndpoint
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
  rescue SignWebauthn::OriginValidationError => e
    Rails.logger.error(
      JitLogEvent.format(
        "#{passkey_registration_log_prefix}.origin_validation_failed",
        message: e.message,
      ),
    )
    render json: { error: I18n.t("errors.webauthn.origin_invalid") }, status: :forbidden
  rescue SignWebauthn::ChallengeError, WebAuthn::Error, ArgumentError => e
    Rails.logger.error(
      JitLogEvent.format(
        "#{passkey_registration_log_prefix}.options_failed",
        error_class: e.class.name,
        message: e.message,
      ),
    )
    render json: { error: I18n.t("errors.webauthn.options_failed") }, status: :unprocessable_content
  end

  def verify_passkey_registration
    challenge_id = params[:challenge_id]
    return render_missing_challenge_id if challenge_id.blank?

    with_challenge(challenge_id, purpose: :registration) do |challenge|
      credential = build_registration_credential
      verify_registration_credential!(credential, challenge)

      passkey = commit_passkey_ceremony!(credential, challenge_id)

      render_verification_success(passkey)
    end
  rescue SignWebauthn::ChallengeNotFoundError,
         SignWebauthn::ChallengeExpiredError => e
    Rails.logger.warn(JitLogEvent.format("#{passkey_registration_log_prefix}.challenge_error", message: e.message))
    render json: { error: I18n.t("errors.webauthn.challenge_invalid") }, status: :bad_request
  rescue SignWebauthn::ChallengePurposeMismatchError => e
    Rails.logger.warn(
      JitLogEvent.format(
        "#{passkey_registration_log_prefix}.challenge_purpose_mismatch",
        message: e.message,
      ),
    )
    render json: { error: I18n.t("errors.webauthn.challenge_invalid") }, status: :bad_request
  rescue WebAuthn::Error => e
    Rails.logger.warn(JitLogEvent.format("#{passkey_registration_log_prefix}.failed", message: e.message))
    render json: { error: I18n.t("errors.webauthn.verification_failed") },
           status: :unprocessable_content
  rescue IdentityPasskeyCeremonyContract::Error => e
    Rails.logger.warn(JitLogEvent.format("#{passkey_registration_log_prefix}.commit_failed", message: e.message))
    render json: { error: I18n.t("errors.webauthn.verification_failed") },
           status: :unprocessable_content
  rescue ActiveRecord::RecordNotUnique
    render json: { error: I18n.t("errors.webauthn.credential_already_registered") }, status: :conflict
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn(JitLogEvent.format("#{passkey_registration_log_prefix}.persist_failed", message: e.message))
    render_passkey_persist_failed(e.record)
  end

  def credential_params
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

  def render_missing_challenge_id
    render json: {
      error: I18n.t("errors.webauthn.challenge_id_required"),
    }, status: :bad_request
  end

  def build_registration_credential
    WebAuthn::Credential.from_create(credential_params.to_h, relying_party: webauthn_relying_party)
  end

  def verify_registration_credential!(credential, challenge)
    credential.verify(challenge)
  end

  def commit_passkey_ceremony!(credential, challenge_id)
    candidate = IdentityPasskeyCeremonyResultIssuer::Candidate.new(
      webauthn_id: credential.id,
      public_key: credential.public_key,
      sign_count: credential.sign_count,
      description: passkey_description,
      transports: credential_params[:transports],
    )
    commit = finish_passkey_ceremony!(
      surface: passkey_registration_surface,
      actor: passkey_registration_actor,
      session_ref: current_session_public_id,
      candidate: candidate,
      challenge_id: challenge_id,
    )
    reset_passkey_ceremony_session!
    commit.passkey
  end

  def render_verification_success(passkey)
    recovery_passcode_top_up = top_up_recovery_passcodes_after_passkey_registration
    redirect_url =
      if recovery_passcode_top_up.raw_values.any?
        recovery_passcode_reveal_url(recovery_passcode_top_up.raw_values)
      else
        passkey_registration_redirect_url
      end

    render json: {
      status: "ok",
      passkey_id: passkey.id,
      redirect_url: bootstrap_return_path(redirect_url),
    }, status: :created
  end

  def render_passkey_persist_failed(record)
    render json: { error: record.errors.full_messages.to_sentence }, status: :unprocessable_content
  end

  def passkey_description
    params[:description].presence || I18n.t("sign.default_passkey_description")
  end

  def verification_required_action?
    step_up_bootstrap_active? && %w(new create options verification).include?(action_name)
  end

  def verification_scope
    "settings_passkey"
  end

  def passkey_registration_existing_credentials
    passkey_registration_passkeys.map { |passkey| { id: passkey.webauthn_id } }
  end

  def top_up_recovery_passcodes_after_passkey_registration
    RecoveryPasscodeTopUp.call(
      actor: recovery_passcode_top_up_actor,
      credential_class: recovery_passcode_top_up_credential_class,
      target_count: RecoveryPasscodeTopUp::TARGET_ACTIVE_RECOVERY_PASSCODES,
    )
  end

  def recovery_passcode_top_up_actor
    raise NotImplementedError, "#{self.class} must define #recovery_passcode_top_up_actor"
  end

  def recovery_passcode_top_up_credential_class
    raise NotImplementedError, "#{self.class} must define #recovery_passcode_top_up_credential_class"
  end

  def recovery_passcode_reveal_url(raw_values)
    return if raw_values.blank?

    reveal = IdentityOneTimeReveal.issue!(
      actor: recovery_passcode_top_up_actor,
      session_nonce: recovery_passcode_top_up_actor.public_id,
      value: raw_values,
      purpose: recovery_passcode_reveal_purpose,
      metadata: recovery_passcode_reveal_metadata,
    )
    recovery_passcode_reveal_redirect_url(reveal.token)
  end

  def recovery_passcode_reveal_purpose
    case passkey_registration_surface
    when "app"
      "client.recovery_secret_credential"
    when "com"
      "visitor.recovery_secret_credential"
    else
      "#{passkey_registration_surface}.recovery_passcodes"
    end
  end

  def recovery_passcode_reveal_metadata
    {}
  end

  def recovery_passcode_reveal_redirect_url(token)
    raise NotImplementedError, "#{self.class} must define #recovery_passcode_reveal_redirect_url"
  end

  def passkey_registration_log_prefix
    "webauthn.registration"
  end
end
