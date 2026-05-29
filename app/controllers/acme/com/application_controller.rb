# typed: false
# frozen_string_literal: true

module Acme
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

      AUTHENTICATION_MODE = :deny_all

      authorize :user, through: :current_policy_user

      allow_browser versions: :modern

      # NOTE: Order matters (dependencies rely on this sequence)
      # Layer order: RateLimit -> CurrentContext -> Preference -> AuthN ->
      # CurrentActor -> side-effect reflection -> Verification -> AuthZ
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

      # NOTE: rewrite in production.
      # FIXME: Resolve the URL issues before deploying.
      protect_from_forgery using: :header_or_legacy_token,
                           trusted_origins: Jit::HostOriginEnv.trusted_origins(
                             ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost"),
                           ),
                           with: :exception

      public

      def oidc_client_id
        "acme_com"
      end

      def oidc_sign_host
        ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
      end
    end
  end
end
