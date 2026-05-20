# typed: false
# frozen_string_literal: true

module Sign
  module PasskeyVerificationFlow
    extend ActiveSupport::Concern

    def verification
      challenge_id = params[:challenge_id]
      return render_error("errors.webauthn.challenge_id_required", :bad_request) if challenge_id.blank?

      challenge_data = peek_challenge(challenge_id)
      return render_error("errors.webauthn.challenge_invalid", :bad_request) unless challenge_data

      actor_id = normalize_passkey_actor_id(challenge_data[passkey_challenge_actor_id_key])

      with_challenge(challenge_id, purpose: :authentication) do |challenge|
        verify_and_login(challenge, actor_id)
      end
    rescue Sign::Webauthn::ChallengeNotFoundError, Sign::Webauthn::ChallengeExpiredError => e
      Rails.logger.warn("WebAuthn challenge error: #{e.message}")
      emit_passkey_auth_failed(reason: "challenge_invalid")
      render_error("errors.webauthn.challenge_invalid", :bad_request)
    rescue Sign::Webauthn::ChallengePurposeMismatchError => e
      Rails.logger.warn("WebAuthn challenge purpose mismatch: #{e.message}")
      emit_passkey_auth_failed(reason: "challenge_purpose_mismatch")
      render_error("errors.webauthn.challenge_invalid", :bad_request)
    rescue WebAuthn::SignCountVerificationError => e
      Rails.logger.warn("WebAuthn sign count verification failed: #{e.message}")
      emit_passkey_auth_failed(reason: "sign_count_mismatch")
      render_error("errors.webauthn.sign_count_mismatch", :unauthorized)
    rescue WebAuthn::Error => e
      Rails.logger.warn("WebAuthn authentication failed: #{e.message}")
      emit_passkey_auth_failed(reason: "verification_failed")
      render_error("errors.webauthn.verification_failed", :unauthorized)
    end

    private

    def emit_passkey_auth_failed(reason: nil)
      actor_key = passkey_challenge_actor_id_key.to_sym
      actor_id = defined?(@_risk_actor_id) ? @_risk_actor_id : nil
      return unless actor_id

      Sign::Risk::Emitter.emit("auth_failed", actor_key => actor_id, :ip => request&.remote_ip, :reason => reason)
    rescue StandardError
      # Best-effort: do not let risk emission failures disrupt the auth flow
    end

    def passkey_challenge_actor_id_key
      raise NotImplementedError, "#{self.class} must define #passkey_challenge_actor_id_key"
    end

    def normalize_passkey_actor_id(actor_id)
      return actor_id if actor_id.is_a?(Integer) || actor_id.nil?

      Integer(actor_id, exception: false) || actor_id
    end
  end
end
