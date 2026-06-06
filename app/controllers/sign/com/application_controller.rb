# typed: false
# frozen_string_literal: true

module Sign
  module Com
    class ApplicationController < ActionController::Base
      include ::RateLimit
      include ::Session
      include ::PreferenceGlobal
      include ::PreferenceAdoption
      include ::AuthenticationVisitor
      include ::SignErrorResponses
      include ::SessionLimitGate
      include ::AuthorizationAudit
      include ::AuthenticationCredentialInventoryReader
      include ::AuthorizationVisitor
      include ::VerificationVisitor
      include ActionPolicy::Controller
      include ::RestrictedSessionGuard
      include SignComRouteAliasHelper
      include ::ActorSupport
      include ::Finisher

      AUTHENTICATION_MODE = :deny_all

      allow_browser versions: :modern

      protect_from_forgery using: :header_or_legacy_token,
                           trusted_origins: JitHostOriginEnv.trusted_origins(
                             ENV.fetch("ID_CORPORATE_URL", "id.com.localhost"),
                           ),
                           with: :exception

      authorize :user, through: :current_policy_user
      authorize :actor, through: :current_actor
      rescue_from AuthenticationBase::LoginCooldownError, with: :render_login_cooldown
      rescue_from ApplicationError, with: :handle_application_error
      rescue_from ActionController::InvalidCrossOriginRequest, with: :handle_csrf_failure
      rescue_from ActionPolicy::Unauthorized, with: :handle_authorization_error
      helper_method :current_actor, :current_account, :current_session_public_id, :current_session_restricted?,
                    :signed_pt_param, :current_visitor, :logged_in?, :active_visitor?, :logged_in_visitor?

      helper Sign::Com::ApplicationHelper
      # Surface-wide default web request limit (defense-in-depth baseline).
      # RateLimit stays a side-effect-free helper; the limit and its numeric
      # value are declared here on the inheriting controller.
      rate_limit(
        to: 300,
        within: 1.minute,
        by: -> { request.remote_ip },
        scope: "sign_com_default_web",
        name: "default_web",
        store: rate_limit_store,
        with: -> { render_rate_limited(rule_name: "sign_com_default_web", retry_after: 60) },
      )
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

      def current_verification_actor
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
        acme_com_dashboard_url(ri: params[:ri], host: ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost"))
      end

      def after_login_allows_other_host?
        true
      end

      def enforce_required_telephone_registration!
        return unless request.format.html?
        return unless current_visitor&.respond_to?(:verified_telephone?)
        return if current_visitor.verified_telephone?
        return if telephone_registration_allowed_path?

        redirect_to(
          new_sign_com_settings_telephones_registration_path(ri: params[:ri]),
          notice: t("sign.app.registration.telephone.create.verification_code_sent"),
        )
      end

      def telephone_registration_allowed_path?
        allowed = [
          "sign/com/settings/telephones/registrations",
          "sign/com/sign_outs",
        ]
        allowed.include?(controller_path)
      end

      def cross_host_redirect_allowed?
        true
      end
    end
  end
end
