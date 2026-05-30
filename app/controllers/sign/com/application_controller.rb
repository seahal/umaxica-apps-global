# typed: false
# frozen_string_literal: true

module Sign
  module Com
    class ApplicationController < ActionController::Base
      include ::RateLimit

      include ::Session

      include ::Preference::Global

      include ::Preference::Adoption

      include ::Authentication::Visitor

      include ::Authentication::CredentialInventoryReader

      include ::Authorization::Visitor

      include ::Verification::Visitor

      include ActionPolicy::Controller

      include ::RestrictedSessionGuard

      include Sign::Com::RouteAliasHelper

      include ::ActorSupport

      include ::Finisher

      AUTHENTICATION_MODE = :deny_all

      authorize :user, through: :current_policy_user

      helper Sign::Com::ApplicationHelper

      protect_from_forgery using: :header_or_legacy_token,
                           trusted_origins: Jit::HostOriginEnv.trusted_origins(
                             ENV.fetch("ID_CORPORATE_URL", "id.com.localhost"),
                           ),
                           with: :exception

      before_action :check_default_rate_limit
      before_action :set_current_context
      before_action :reset_flash
      before_action :set_preferences_cookie
      before_action :resolve_param_context
      before_action :set_region

      before_action :transparent_refresh_access_token, unless: -> { request.format.json? }
      before_action :set_current_actor
      before_action :apply_localization_preferences
      before_action :set_color_theme
      before_action :enforce_withdrawal_gate!
      before_action :enforce_restricted_session_guard!
      before_action :enforce_sign_in_selector_gate!
      before_action :enforce_required_telephone_registration!
      before_action :enforce_verification_if_required
      before_action :enforce_access_policy!
      before_action :set_current_observability
      prepend_around_action :with_actor_lifecycle

      class << self
        def local_prefixes
          prefixes = Array(super)
          app_prefix = controller_path.sub("/com/", "/app/")
          prefixes.include?(app_prefix) ? prefixes : prefixes + [app_prefix]
        end
      end

      private

      def actor_staff?
        false
      end

      def current_actor
        current_visitor
      end

      def verification_model
        VisitorVerification
      end

      def verification_token_foreign_key
        :visitor_token_id
      end

      def identity_email_model
        VisitorEmail
      end

      def identity_telephone_model
        VisitorTelephone
      end

      def identity_from_email_record(record)
        record&.visitor
      end

      def identity_from_telephone_record(record)
        record&.visitor
      end

      def actor_verification_path(attrs = {})
        sign_com_verification_path(attrs)
      end

      def verification_redirect_path(pt: nil, scope_override: nil)
        attrs = { ri: params[:ri], pt: pt }
        scope = scope_override.to_s.presence || verification_scope.to_s.presence
        attrs[:scope] = scope if scope
        sign_com_verification_path(attrs)
      end

      def verification_setup_redirect_path(pt: nil)
        new_sign_com_verification_setup_path(ri: params[:ri], pt: pt || encoded_step_up_pt)
      end

      def after_login_path
        sign_com_dashboard_path
      end

      def enforce_required_telephone_registration!
        return unless request.format.html?
        return unless current_visitor&.respond_to?(:verified_telephone?)
        return if current_visitor.verified_telephone?
        return if telephone_registration_allowed_path?

        redirect_to(
          new_sign_com_configuration_telephones_registration_path(ri: params[:ri]),
          notice: t("sign.app.registration.telephone.create.verification_code_sent"),
        )
      end

      def telephone_registration_allowed_path?
        allowed = [
          "sign/com/configuration/telephones/registrations",
          "sign/com/sign_outs",
        ]
        allowed.include?(controller_path)
      end
    end
  end
end
