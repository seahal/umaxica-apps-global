# typed: false
# frozen_string_literal: true

require "json"

module Sign
  module VerificationPasskeyChecks
    extend ActiveSupport::Concern

    private

    def prepare_passkey_challenge!
      allow_credentials = verification_passkeys_scope.active.map { |pk| { id: pk.webauthn_id } }
      if allow_credentials.empty?
        @verification_errors = [I18n.t(verification_no_passkey_i18n_key)]
        return false
      end

      @passkey_challenge_id, @passkey_request_options =
        create_authentication_challenge(allow_credentials: allow_credentials)
      true
    end

    def verify_passkey!
      challenge_id = verification_params[:challenge_id].to_s
      credential_json = verification_params[:credential_json].to_s
      if challenge_id.blank? || credential_json.blank?
        @verification_errors = ["パスキー認証データが不足しています"]
        return false
      end

      credential_hash = JSON.parse(credential_json)
      challenge_id = resolve_verification_challenge_id(challenge_id)

      with_challenge(challenge_id, purpose: :authentication) do |challenge|
        credential = WebAuthn::Credential.from_get(
          credential_hash,
          relying_party: webauthn_relying_party,
        )
        passkey = verification_passkey_model.find_by(webauthn_id: credential.id)
        unless passkey && passkey_actor_matches?(passkey)
          @verification_errors = [I18n.t("errors.webauthn.credential_not_found")]
          next false
        end

        credential.verify(
          challenge,
          public_key: passkey.public_key,
          sign_count: passkey.sign_count,
        )
        passkey.update!(sign_count: credential.sign_count)
        true
      end
    rescue Sign::Webauthn::ChallengeNotFoundError,
           Sign::Webauthn::ChallengeExpiredError,
           Sign::Webauthn::ChallengePurposeMismatchError
      @verification_errors = [I18n.t("errors.webauthn.challenge_invalid")]
      false
    rescue WebAuthn::Error, JSON::ParserError
      @verification_errors = [I18n.t("errors.webauthn.verification_failed")]
      false
    end

    def resolve_verification_challenge_id(challenge_id)
      return challenge_id unless respond_to?(:peek_challenge, true)
      return challenge_id if peek_challenge(challenge_id).present?

      challenges = session[Sign::Webauthn::CHALLENGE_SESSION_KEY] || {}
      authentication_challenges = challenges.select { |_, data| data["purpose"] == "authentication" }
      return authentication_challenges.keys.first if authentication_challenges.one?

      challenge_id
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
end
