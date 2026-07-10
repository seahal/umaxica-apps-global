# typed: false
# frozen_string_literal: true

module SignPasskeySignInFlow
  extend ActiveSupport::Concern

  private

  def verify_and_login(challenge, actor_id)
    @_risk_actor_id = actor_id
    credential = build_authentication_credential
    return unless credential

    passkey = passkey_sign_in_model.find_by(webauthn_id: credential.id)

    unless passkey && passkey_belongs_to_challenge_actor?(passkey, actor_id)
      Rails.logger.warn(passkey_owner_mismatch_log_message)
      emit_passkey_auth_failed(reason: "credential_not_found")
      return render_error("errors.webauthn.credential_not_found", :unauthorized)
    end

    return unless allow_passkey_sign_in?(passkey)

    verify_authentication_credential!(credential: credential, passkey: passkey, challenge: challenge)
    handle_login_result(perform_passkey_sign_in(passkey))
  end

  def passkey_sign_in_model
    raise NotImplementedError, "#{self.class} must define #passkey_sign_in_model"
  end

  def passkey_belongs_to_challenge_actor?(_passkey, _actor_id)
    raise NotImplementedError, "#{self.class} must define #passkey_belongs_to_challenge_actor?"
  end

  def passkey_owner_mismatch_log_message
    "WebAuthn: Credential not found or actor mismatch"
  end

  def allow_passkey_sign_in?(_passkey)
    true
  end

  def perform_passkey_sign_in(_passkey)
    raise NotImplementedError, "#{self.class} must define #perform_passkey_sign_in"
  end
end
