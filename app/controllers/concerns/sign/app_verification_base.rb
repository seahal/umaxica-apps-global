# typed: false
# frozen_string_literal: true

module Sign
  module AppVerificationBase
    extend ActiveSupport::Concern

    STEP_UP_TTL = 15.minutes
    EMAIL_OTP_RESEND_COOLDOWN = StepUp::Cooldowns::WINDOWS.fetch(:email_otp)
    STEP_UP_SESSION_KEY = :step_up
    EMAIL_OTP_SESSION_KEY = :step_up_email_otp

    ALLOWED_SCOPES = StepUp::ScopeCatalog::APP

    included do
      include ::Preference::Global
      include Common::Otp
      include ::Verification::Client
      include Sign::Webauthn
      include Sign::VerificationTiming
      include Sign::VerificationCommonBase
      include Sign::VerificationAuditAndCookie
      include Sign::VerificationStepUpSessionStore
      include Sign::VerificationStepUpLifecycle
      include Sign::VerificationPasskeyChecks
      include Sign::VerificationTotpChecks

      before_action :apply_localization_preferences
      before_action :authenticate_client!
      before_action :set_actor_token
      before_action :require_ri!
      before_action :enforce_step_up_prereqs!
    end

    private

    def verification_params
      params.fetch(:verification, {}).permit(
        :code, :challenge_id, :credential_json, :scope, :return_to,
        :rt,
      )
    end

    def email_otp_session_active?
      current_step_up_session.present? && Rails.cache.exist?(email_otp_cache_key)
    end

    def ensure_email_nonce!
      Rails.cache.fetch(
        email_nonce_cache_key,
        expires_in: [current_step_up_session.discarded_at - Time.current, 0].max,
      ) do
        SecureRandom.urlsafe_base64(16)
      end
    end

    def current_step_up_scope
      current_step_up_session&.scope
    end

    def current_step_up_return_to_param
      return_to = current_step_up_session&.return_to
      return if return_to.blank?

      issue_step_up_rt(return_to)
    end

    def verification_recovery_redirect_params
      attrs = { ri: params[:ri] }

      scope = incoming_scope
      attrs[:scope] = scope if scope.present?

      return_to = incoming_return_to
      attrs[:return_to] = return_to if return_to.present?

      attrs
    end

    def valid_step_up_session?(rs)
      rs.present? &&
        rs.discarded_at > Time.current &&
        rs.user_token_id == actor_token.id &&
        rs.status == "PENDING" &&
        rs.scope.present? &&
        rs.return_to.present?
    end

    def restore_step_up_session_from_params!
      scope = incoming_scope
      return_to = incoming_return_to
      return false if scope.blank? || return_to.blank?

      start_step_up_session!(scope: scope, return_to_param: return_to)
      true
    rescue ActionController::BadRequest
      false
    end

    def incoming_scope
      verification_params[:scope].to_s.presence ||
        request_parameters["scope"].to_s.presence
    end

    def incoming_return_to
      verification_params[:return_to].to_s.presence ||
        verification_params[:rt].to_s.presence ||
        request_parameters["return_to"].to_s.presence ||
        request_parameters["rt"].to_s.presence
    end

    def request_parameters
      return request.parameters if respond_to?(:request, true) && request.respond_to?(:parameters)
      return params if respond_to?(:params, true)

      {}
    end

    def step_up_session_model = ClientStepUpSession

    def step_up_session_token_foreign_key = :user_token_id

    def handle_invalid_step_up_session!
      clear_step_up_state!
      destroy_current_step_up_session!

      if restore_step_up_session_from_params! && valid_step_up_session?(current_step_up_session)
        return true
      end

      safe_redirect_to(
        sign_app_configuration_path(ri: params[:ri]),
        fallback: sign_app_root_path(ri: params[:ri]),
        alert: I18n.t("auth.step_up.session_expired"),
      )
      false
    end

    def verification_unavailable_redirect_path
      sign_app_verification_path(ri: params[:ri])
    end

    def clear_step_up_state!
      Rails.cache.delete(email_otp_cache_key) if current_step_up_session.present?
    end

    def verification_model
      ClientVerification
    end

    def verification_success_event_id
      ClientChronicleEvent::STEP_UP_VERIFIED
    end

    def verification_success_notice_key
      "sign.app.verification.success.complete"
    end

    def verification_success_fallback_path
      sign_app_verification_path(ri: params[:ri])
    end

    def verification_audit_event_class = ClientChronicleEvent

    def verification_audit_level_class = ClientChronicleLevel

    def verification_default_activity_level_id = ClientChronicleLevel::NOTHING

    def verification_activity_model = ClientChronicle

    def current_verification_actor = current_client

    def verification_actor_type = "Client"

    def verification_passkeys_scope
      current_client.client_passkeys
    end

    def verification_passkey_model
      ClientPasskey
    end

    def passkey_actor_matches?(passkey)
      passkey.user_id == current_client.id
    end

    def verification_no_passkey_i18n_key
      "sign.app.verification.errors.no_passkey"
    end

    def active_totp_credentials
      current_client.client_one_time_passwords
        .where(user_one_time_password_status_id: ClientOneTimePasswordStatus::ACTIVE)
        .order(created_at: :desc)
    end

    def send_email_otp!
      user_email =
        current_client.client_emails.where(
          user_email_status_id: AuthMethodGuard::VERIFIED_EMAIL_STATUSES,
        ).order(created_at: :desc).first
      unless user_email
        @verification_errors = [I18n.t("sign.app.verification.errors.email_not_verified")]
        return false
      end

      secret, counter, pass_code = generate_hotp_code
      Rails.cache.write(
        email_otp_cache_key, {
          "secret" => secret,
          "counter" => counter,
        }, expires_in: [current_step_up_session.discarded_at - Time.current, 0].max,
      )

      enqueue_step_up_email_otp!(
        hotp_token: pass_code,
        email_address: user_email.address,
        public_id: current_client.public_id,
      )

      true
    end

    def enqueue_step_up_email_otp!(hotp_token:, email_address:, public_id:)
      SolidQueue::Record.connected_to(role: :writing) do
        Email::App::OtpMailer.with(
          encrypted_hotp_token: Outbound::SensitivePayload.encrypt_email_otp(hotp_token),
          email_address: email_address,
          public_id: public_id,
          verification_token: nil,
        ).create.deliver_later
      end
    end

    def verify_email_otp!
      code = verification_params[:code].to_s
      unless code.match?(/\A\d{6}\z/)
        @verification_errors = [I18n.t("sign.app.verification.errors.invalid_code")]
        return false
      end

      data = Rails.cache.read(email_otp_cache_key)
      unless data
        @verification_errors = [I18n.t("sign.app.verification.errors.resend_required")]
        return false
      end

      if current_step_up_session.discarded_at <= Time.current
        @verification_errors = [I18n.t("sign.app.verification.errors.code_expired")]
        return false
      end

      ok = verify_hotp_code(secret: data["secret"], counter: data["counter"], pass_code: code)
      unless ok
        @verification_errors = [I18n.t("sign.app.verification.errors.incorrect_code")]
        return false
      end

      true
    end

    def email_otp_cache_key
      "step_up_session:#{current_step_up_session.id}:email_otp"
    end

    def email_nonce_cache_key
      rs = current_step_up_session
      key_id = rs.respond_to?(:id) ? rs.id : rs.hash
      "step_up_session:#{key_id}:email_nonce"
    end

    def email_otp_resend_cache_key
      "step_up_session:#{current_step_up_session.id}:email_otp_resend"
    end

    def email_otp_resend_rate_limited?
      Rails.cache.exist?(email_otp_resend_cache_key)
    end

    def stamp_email_otp_resend!
      Rails.cache.write(
        email_otp_resend_cache_key,
        Time.current.to_i,
        expires_in: EMAIL_OTP_RESEND_COOLDOWN,
      )
    end
  end
end
