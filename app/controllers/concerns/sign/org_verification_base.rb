# typed: false
# frozen_string_literal: true

module Sign
  module OrgVerificationBase
    extend ActiveSupport::Concern

    REAUTH_TTL = 15.minutes
    REAUTH_SESSION_KEY = :reauth

    ALLOWED_SCOPES = {
      "configuration_passkey" => %r{\A/configuration/passkeys},
      "configuration_mfa" => %r{\A/configuration/mfa},
      "configuration_secret" => %r{\A/configuration/secrets},
      "withdrawal" => %r{\A/configuration/withdrawal},
    }.freeze

    included do
      include ::Preference::Global
      include Common::Otp
      include ::Authentication::Staff
      include ::Verification::Staff
      include Sign::Webauthn
      include Sign::VerificationTiming
      include Sign::VerificationCommonBase
      include Sign::VerificationAuditAndCookie
      include Sign::VerificationReauthSessionStore
      include Sign::VerificationReauthLifecycle
      include Sign::VerificationPasskeyChecks

      before_action :authenticate_staff!
      before_action :set_actor_token
      before_action :require_ri!
      before_action :enforce_step_up_prereqs!

      # Override methods from sub-concerns here to ensure they take precedence
      # in Ruby's method resolution order (methods defined in included block
      # are defined on the including class AFTER submodules are mixed in)

      define_method(:reauth_actor_id) { current_staff.id }

      define_method(:valid_reauth_session?) do |rs|
        rs.present? &&
          rs["expires_at"].to_i > Time.current.to_i &&
          rs["user_id"] == current_staff.id &&
          rs["scope"].present?
      end

      define_method(:handle_invalid_reauth_session!) do
        clear_reauth_state!
        safe_redirect_to(
          sign_org_configuration_path(ri: params[:ri]),
          fallback: "/configuration",
          alert: I18n.t("auth.step_up.session_expired"),
        )
        false
      end

      define_method(:clear_reauth_state!) do
        session.delete(REAUTH_SESSION_KEY)
      end

      define_method(:verification_model) { StaffVerification }

      define_method(:verification_success_event_id) { StaffChronicleEvent::STEP_UP_VERIFIED }

      define_method(:verification_success_notice_key) { "sign.org.verification.success.complete" }

      define_method(:verification_success_fallback_path) { sign_org_verification_path(ri: params[:ri]) }

      define_method(:verification_audit_event_class) { StaffChronicleEvent }

      define_method(:verification_audit_level_class) { StaffChronicleLevel }

      define_method(:verification_default_activity_level_id) { StaffChronicleLevel::NOTHING }

      define_method(:verification_activity_model) { StaffChronicle }

      define_method(:current_verification_actor) { current_staff }

      define_method(:verification_actor_type) { "Staff" }

      define_method(:verification_passkeys_scope) { current_staff.staff_passkeys }

      define_method(:verification_passkey_model) { StaffPasskey }

      define_method(:passkey_actor_matches?) { |passkey| passkey.staff_id == current_staff.id }

      define_method(:verification_no_passkey_i18n_key) { "sign.org.verification.errors.no_passkey" }
    end

    private

    def verification_params
      params.fetch(:verification, {}).permit(:code, :challenge_id, :credential_json)
    end

    def verification_unavailable_redirect_path
      sign_org_verification_path(ri: params[:ri])
    end

    # Note: These methods are also defined in the included block above
    # to ensure they override methods from sub-concerns.
    # They're kept here as fallback documentation and for any code
    # that might call them via super or other means.

    def reauth_actor_id
      current_staff.id
    end

    def valid_reauth_session?(rs)
      rs.present? &&
        rs["expires_at"].to_i > Time.current.to_i &&
        rs["user_id"] == current_staff.id &&
        rs["scope"].present?
    end

    def handle_invalid_reauth_session!
      clear_reauth_state!
      safe_redirect_to(
        sign_org_configuration_path(ri: params[:ri]),
        fallback: "/configuration",
        alert: I18n.t("auth.step_up.session_expired"),
      )
      false
    end

    def clear_reauth_state!
      session.delete(REAUTH_SESSION_KEY)
    end

    def verification_model
      StaffVerification
    end

    def verification_success_event_id
      StaffChronicleEvent::STEP_UP_VERIFIED
    end

    def verification_success_notice_key
      "sign.org.verification.success.complete"
    end

    def verification_success_fallback_path
      sign_org_verification_path(ri: params[:ri])
    end

    def verification_audit_event_class = StaffChronicleEvent

    def verification_audit_level_class = StaffChronicleLevel

    def verification_default_activity_level_id = StaffChronicleLevel::NOTHING

    def verification_activity_model = StaffChronicle

    def current_verification_actor = current_staff

    def verification_actor_type = "Staff"

    def verification_passkeys_scope
      current_staff.staff_passkeys
    end

    def verification_passkey_model
      StaffPasskey
    end

    def passkey_actor_matches?(passkey)
      passkey.staff_id == current_staff.id
    end

    def verification_no_passkey_i18n_key
      "sign.org.verification.errors.no_passkey"
    end
  end
end
