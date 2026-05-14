# typed: false
# frozen_string_literal: true

module Sign
  module OrgVerificationBase
    extend ActiveSupport::Concern

    REAUTH_TTL = 15.minutes
    REAUTH_SESSION_KEY = :reauth

    ALLOWED_SCOPES = {
      "social_unlink" => %r{\A/social/},
      "session_revoke_all" => %r{\A/configuration/sessions},
      "withdrawal" => %r{\A/configuration/withdrawal},
      "configuration_email" => %r{\A/configuration/emails},
      "configuration_telephone" => %r{\A/configuration/telephones},
      "configuration_passkey" => %r{\A/configuration/passkeys},
      "configuration_mfa" => %r{\A/configuration/challenge},
      "configuration_secret" => %r{\A/configuration/secrets},
    }.freeze

    included do
      include ::Preference::Global
      include Common::Otp
      include ::Authentication::Operator
      include ::Verification::Operator
      include Sign::Webauthn
      include Sign::VerificationTiming
      include Sign::VerificationCommonBase
      include Sign::VerificationAuditAndCookie
      include Sign::VerificationReauthSessionStore
      include Sign::VerificationReauthLifecycle
      include Sign::VerificationPasskeyChecks

      before_action :authenticate_operator!
      before_action :set_actor_token
      before_action :require_ri!
      before_action :enforce_step_up_prereqs!

      # Override methods from sub-concerns here to ensure they take precedence
      # in Ruby's method resolution order (methods defined in included block
      # are defined on the including class AFTER submodules are mixed in)

      define_method(:valid_reauth_session?) do |rs|
        rs.present? &&
          rs.lapses_at > Time.current &&
          rs.staff_token_id == actor_token.id &&
          rs.status == "PENDING" &&
          rs.scope.present? &&
          rs.return_to.present?
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
        true
      end

      define_method(:verification_model) { OperatorVerification }

      define_method(:verification_success_event_id) { OperatorChronicleEvent::STEP_UP_VERIFIED }

      define_method(:verification_success_notice_key) { "sign.org.verification.success.complete" }

      define_method(:verification_success_fallback_path) { sign_org_verification_path(ri: params[:ri]) }

      define_method(:verification_audit_event_class) { OperatorChronicleEvent }

      define_method(:verification_audit_level_class) { OperatorChronicleLevel }

      define_method(:verification_default_activity_level_id) { OperatorChronicleLevel::NOTHING }

      define_method(:verification_activity_model) { OperatorChronicle }

      define_method(:current_verification_actor) { current_operator }

      define_method(:verification_actor_type) { "Operator" }

      define_method(:verification_passkeys_scope) { current_operator.staff_passkeys }

      define_method(:verification_passkey_model) { OperatorPasskey }

      define_method(:passkey_actor_matches?) { |passkey| passkey.staff_id == current_operator.id }

      define_method(:verification_no_passkey_i18n_key) { "sign.org.verification.errors.no_passkey" }
    end

    private

    def verification_params
      params.fetch(:verification, {}).permit(:code, :challenge_id, :credential_json, :scope, :return_to, :rt)
    end

    def verification_unavailable_redirect_path
      sign_org_verification_path(ri: params[:ri])
    end

    def reauth_session_model = OperatorReauthSession

    def reauth_session_token_foreign_key = :staff_token_id
  end
end
