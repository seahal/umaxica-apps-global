# typed: false
# frozen_string_literal: true

module Core
  module Org
    class ApplicationController < ActionController::Base
      include ::RateLimit
      include ::JumpRt::ReturnVerification

      include ::Session

      include ::Preference::Global

      include ::Preference::Adoption

      include ::Authentication::Operator

      include ::Authorization::Operator

      include ::Verification::Operator

      include ActionPolicy::Controller

      include ::Oidc::SsoInitiator

      include ::ActorSupport

      include ::Finisher

      AUTHENTICATION_MODE = :deny_all

      authorize :user, through: :current_policy_user

      allow_browser versions: :modern

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
      before_action :enforce_verification_if_required
      before_action :enforce_access_policy!
      before_action :set_current_observability
      prepend_around_action :with_actor_lifecycle

      protect_from_forgery using: :header_or_legacy_token,
                           trusted_origins: Jit::HostOriginEnv.trusted_origins(
                             ENV.fetch("CORE_STAFF_URL", "www.jp.umaxica.org"),
                           ),
                           with: :exception

      def oidc_client_id
        "core_org"
      end

      def oidc_sign_host
        ENV.fetch("ID_STAFF_URL", "id.org.localhost")
      end
    end
  end
end
