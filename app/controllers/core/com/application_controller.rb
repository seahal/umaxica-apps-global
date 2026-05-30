# typed: false
# frozen_string_literal: true

module Core
  module Com
    class ApplicationController < ActionController::Base
      include ::RateLimit
      include ::JumpRt::ReturnVerification
      include ::Session
      include ::Preference::Global
      include ::Authentication::Visitor
      include ::Authorization::Visitor
      include ::Verification::Visitor
      include ActionPolicy::Controller
      include ::Oidc::SsoInitiator
      include ::ActorSupport
      include ::Finisher

      allow_browser versions: :modern

      protect_from_forgery using: :header_or_legacy_token,
                           trusted_origins: Jit::HostOriginEnv.trusted_origins(
                             ENV.fetch("CORE_CORPORATE_URL", "www.jp.umaxica.com"),
                           ),
                           with: :exception

      AUTHENTICATION_MODE = :deny_all

      authorize :user, through: :current_policy_user

      # Existing jump-return handling runs before rate limiting; keep that order
      # for this extraction and review the risk in a follow-up lifecycle PR.
      before_action :verify_jump_return_rt!, if: :jump_return_rt_request?
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
      before_action :enforce_verification_if_required
      before_action :enforce_access_policy!
      before_action :set_current_observability
      prepend_around_action :with_actor_lifecycle

      def oidc_client_id
        "core_com"
      end

      def oidc_sign_host
        ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
      end
    end
  end
end
