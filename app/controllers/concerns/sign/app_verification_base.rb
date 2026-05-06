# typed: false
# frozen_string_literal: true

module Sign
  module AppVerificationBase
    extend ActiveSupport::Concern

    REAUTH_TTL = 15.minutes
    REAUTH_SESSION_KEY = :reauth
    EMAIL_OTP_SESSION_KEY = :reauth_email_otp

    ALLOWED_SCOPES = {
      "configuration_email" => %r{\A/configuration/emails},
      "configuration_telephone" => %r{\A/configuration/telephones},
      "configuration_passkey" => %r{\A/configuration/passkeys},
      "configuration_mfa" => %r{\A/configuration/mfa},
      "configuration_secret" => %r{\A/configuration/secrets},
      "manage_totp" => %r{\A/configuration/totps},
      "withdrawal" => %r{\A/configuration/withdrawal},
      "social_unlink" => %r{\A/social/},
    }.freeze

    included do
      include ::Preference::Global
      include Common::Otp
      include ::Verification::User
      include Sign::Webauthn
      include Sign::VerificationTiming
      include Sign::VerificationCommonBase
      include Sign::VerificationAuditAndCookie
      include Sign::VerificationReauthSessionStore
      include Sign::VerificationReauthLifecycle
      include Sign::VerificationPasskeyChecks
      include Sign::VerificationTotpChecks

      before_action :authenticate_user!
      before_action :set_actor_token
      before_action :require_ri!
      before_action :enforce_step_up_prereqs!
    end

    private

    def verification_params
      params.fetch(:verification, {}).permit(
        :code, :challenge_id, :credential_json, :scope, :return_to,
        :rd,
      )
    end

    def email_otp_session_active?
      data = session[EMAIL_OTP_SESSION_KEY]
      return false unless data

      Time.current.to_i <= data["expires_at"].to_i
    end

    def ensure_email_nonce!
      rs = current_reauth_session
      rs["email_nonce"] ||= SecureRandom.urlsafe_base64(16)
      session[REAUTH_SESSION_KEY] = rs
      rs["email_nonce"]
    end

    def current_reauth_scope
      current_reauth_session&.fetch("scope", nil)
    end

    def current_reauth_return_to_param
      return_to = current_reauth_session&.fetch("return_to", nil)
      return if return_to.blank?

      Base64.urlsafe_encode64(return_to)
    end

    def verification_recovery_redirect_params
      attrs = { ri: params[:ri] }

      scope = incoming_scope
      attrs[:scope] = scope if scope.present?

      return_to = incoming_return_to
      attrs[:return_to] = return_to if return_to.present?

      attrs
    end

    def valid_reauth_session?(rs)
      rs.present? &&
        rs["expires_at"].to_i > Time.current.to_i &&
        rs["user_id"] == current_user.id &&
        rs["scope"].present? &&
        rs["return_to"].present?
    end

    def restore_reauth_session_from_params!
      scope = incoming_scope
      return_to = incoming_return_to
      return false if scope.blank? || return_to.blank?

      start_reauth_session!(scope: scope, return_to_param: return_to)
      true
    rescue ActionController::BadRequest
      false
    end

    def incoming_scope
      verification_params[:scope].to_s.presence || params[:scope].to_s
    end

    def incoming_return_to
      verification_params[:return_to].to_s.presence ||
        verification_params[:rd].to_s.presence ||
        params[:return_to].to_s.presence ||
        params[:rd].to_s
    end

    def reauth_actor_id
      current_user.id
    end

    def handle_invalid_reauth_session!
      clear_reauth_state!
      if restore_reauth_session_from_params! && valid_reauth_session?(current_reauth_session)
        return true
      end

      safe_redirect_to(
        sign_app_verification_path(verification_recovery_redirect_params),
        fallback: sign_app_verification_path(ri: params[:ri]),
        alert: I18n.t("auth.step_up.session_expired"),
      )
      false
    end

    def verification_unavailable_redirect_path
      sign_app_verification_path(ri: params[:ri])
    end

    def clear_reauth_state!
      session.delete(REAUTH_SESSION_KEY)
      session.delete(EMAIL_OTP_SESSION_KEY)
    end

    def verification_model
      UserVerification
    end

    def verification_success_event_id
      UserChronicleEvent::STEP_UP_VERIFIED
    end

    def verification_success_notice_key
      "sign.app.verification.success.complete"
    end

    def verification_success_fallback_path
      sign_app_verification_path(ri: params[:ri])
    end

    def verification_audit_event_class = UserChronicleEvent

    def verification_audit_level_class = UserChronicleLevel

    def verification_default_activity_level_id = UserChronicleLevel::NOTHING

    def verification_activity_model = UserChronicle

    def current_verification_actor = current_user

    def verification_actor_type = "User"

    def verification_passkeys_scope
      current_user.user_passkeys
    end

    def verification_passkey_model
      UserPasskey
    end

    def passkey_actor_matches?(passkey)
      passkey.user_id == current_user.id
    end

    def verification_no_passkey_i18n_key
      "sign.app.verification.errors.no_passkey"
    end

    def active_totp_credentials
      current_user.user_one_time_passwords
        .where(user_one_time_password_status_id: UserOneTimePasswordStatus::ACTIVE)
        .order(created_at: :desc)
    end

    def send_email_otp!
      user_email =
        current_user.user_emails.where(
          user_email_status_id: UserEmailStatus::VERIFIED,
        ).order(created_at: :desc).first
      unless user_email
        @verification_errors = ["メールアドレスが未確認です"]
        return false
      end

      secret, counter, pass_code = generate_hotp_code
      rs = current_reauth_session
      session[EMAIL_OTP_SESSION_KEY] = {
        "secret" => secret,
        "counter" => counter,
        "expires_at" => rs["expires_at"],
      }

      Email::App::RegistrationMailer.with(
        hotp_token: pass_code,
        email_address: user_email.address,
        public_id: current_user.public_id,
        verification_token: nil,
      ).create.deliver_later

      true
    end

    def verify_email_otp!
      code = verification_params[:code].to_s
      unless code.match?(/\A\d{6}\z/)
        @verification_errors = ["確認コードが不正です"]
        return false
      end

      data = session[EMAIL_OTP_SESSION_KEY]
      unless data
        @verification_errors = ["確認コードの再送信が必要です"]
        return false
      end

      if Time.current.to_i > data["expires_at"].to_i
        @verification_errors = ["確認コードの有効期限が切れました"]
        return false
      end

      ok = verify_hotp_code(secret: data["secret"], counter: data["counter"], pass_code: code)
      unless ok
        @verification_errors = ["確認コードが正しくありません"]
        return false
      end

      true
    end
  end
end
