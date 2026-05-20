# typed: false
# frozen_string_literal: true

module Sign
  module OrgVerificationBase
    extend ActiveSupport::Concern

    STEP_UP_TTL = 15.minutes
    STEP_UP_SESSION_KEY = :step_up

    ALLOWED_SCOPES = StepUp::ScopeCatalog::ORG

    included do
      include ::Preference::Global
      include Common::Otp
      include ::Authentication::Operator
      include ::Verification::Operator
      include Sign::Webauthn
      include Sign::VerificationTiming
      include Sign::VerificationCommonBase
      include Sign::VerificationAuditAndCookie
      include Sign::VerificationStepUpSessionStore
      include Sign::VerificationStepUpLifecycle
      include Sign::VerificationPasskeyChecks

      before_action :apply_localization_preferences
      before_action :authenticate_operator!
      before_action :set_actor_token
      before_action :require_ri!
      before_action :enforce_step_up_prereqs!

      # Override methods from sub-concerns here to ensure they take precedence
      # in Ruby's method resolution order (methods defined in included block
      # are defined on the including class AFTER submodules are mixed in)

      define_method(:valid_step_up_session?) do |rs|
        rs.present? &&
          rs.discarded_at > Time.current &&
          rs.staff_token_id == actor_token.id &&
          rs.status == "PENDING" &&
          rs.scope.present? &&
          rs.return_to.present?
      end

      define_method(:handle_invalid_step_up_session!) do
        clear_step_up_state!
        safe_redirect_to(
          sign_org_configuration_path(ri: params[:ri]),
          fallback: "/configuration",
          alert: I18n.t("auth.step_up.session_expired"),
        )
        false
      end

      define_method(:clear_step_up_state!) do
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

    def step_up_session_model = OperatorStepUpSession

    def step_up_session_token_foreign_key = :staff_token_id
  end
end
