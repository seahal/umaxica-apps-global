# typed: false
# frozen_string_literal: true

require "json"

module SignVerificationPasskeyChecks
  extend ActiveSupport::Concern

  include PasskeyCeremonyContext

  private

  def prepare_passkey_challenge!
    passkeys = verification_passkeys_scope.active
    if passkeys.none?
      @verification_errors = [I18n.t(verification_no_passkey_i18n_key)]
      return false
    end

    @passkey_challenge_id, @passkey_request_options =
      issue_passkey_authentication_challenge(
        allow_credentials: passkeys, actor: verification_passkey_actor, purpose: :step_up,
      )
    true
  end

  def verify_passkey!
    challenge_id = verification_params[:challenge_id].to_s
    credential_json = verification_params[:credential_json].to_s
    if challenge_id.blank? || credential_json.blank?
      @verification_errors = [I18n.t("errors.webauthn.challenge_id_required")]
      return false
    end

    credential_hash = JSON.parse(credential_json)
    challenge = consume_passkey_challenge!(
      challenge_id, purpose: :step_up, actor: verification_passkey_actor,
    )

    passkey = verification_passkey_model.find_by(webauthn_id: credential_hash["id"])
    unless passkey && passkey_actor_matches?(passkey)
      @verification_errors = [I18n.t("errors.webauthn.credential_not_found")]
      return false
    end

    context = Webauthn::AssertionVerifier.verify!(
      credential_params: credential_hash,
      challenge: challenge,
      config: webauthn_relying_party_config,
      public_key: passkey.public_key,
      sign_count: passkey.sign_count,
      purpose: :ordinary_step_up,
    )
    attrs = { sign_count: context.sign_count }
    if passkey.respond_to?(:has_attribute?) && passkey.has_attribute?(:uv_verified_at)
      attrs[:uv_verified_at] = context.verified_at
    end
    passkey.update!(**attrs)
    true
  rescue Webauthn::ChallengeStore::ChallengeError
    @verification_errors = [I18n.t("errors.webauthn.challenge_invalid")]
    false
  rescue Webauthn::AssertionVerifier::VerificationError, WebAuthn::Error, JSON::ParserError
    @verification_errors = [I18n.t("errors.webauthn.verification_failed")]
    false
  end

  def verification_passkey_actor
    current_verification_actor
  end

  def verification_passkeys_scope
    raise NotImplementedError, "#{self.class} must define #verification_passkeys_scope"
  end

  def verification_passkey_model
    raise NotImplementedError, "#{self.class} must define #verification_passkey_model"
  end

  def passkey_actor_matches?(_passkey)
    raise NotImplementedError, "#{self.class} must define #passkey_actor_matches?"
  end

  def verification_no_passkey_i18n_key
    raise NotImplementedError, "#{self.class} must define #verification_no_passkey_i18n_key"
  end
end
