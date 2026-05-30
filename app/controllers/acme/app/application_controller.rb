# typed: false
# frozen_string_literal: true

module Acme
  module App
    class ApplicationController < ActionController::Base
      include ::RateLimit
      include ::JumpRt::ReturnVerification

      include ::Session

      include ::Preference::Global

      include ::Preference::Adoption # FIXME: I hate this line.

      include ::Authentication::Client

      include ::Authorization::Client

      include ::Verification::Client

      include ActionPolicy::Controller # FIXME: I hate this line.

      include ::Oidc::SsoInitiator # FIXME: I hate this line.

      include ::ActorSupport

      include ::Finisher

      AUTHENTICATION_MODE = :deny_all

      authorize :user, through: :current_policy_user

      allow_browser versions: :modern

      # NOTE: Order matters (dependencies rely on this sequence)
      # Layer order: RateLimit -> CurrentContext -> Preference -> AuthN ->
      # CurrentActor -> side-effect reflection -> Verification -> AuthZ
      # Existing jump-return handling runs before rate limiting; keep that order
      # for this extraction and review the risk in a follow-up lifecycle PR.
      before_action :verify_jump_return_rt!, if: :jump_return_rt_request?
      before_action :check_default_rate_limit
      before_action :set_current_context
      before_action :reset_flash
      before_action :set_preferences_cookie # FIXME: I hate this line.
      before_action :resolve_param_context # FIXME: I hate this line.
      before_action :set_region # FIXME: I hate this line.
      before_action :set_locale # FIXME: I hate this line.
      before_action :set_timezone # FIXME: I hate this line.

      before_action :transparent_refresh_access_token, unless: -> { request.format.json? } # FIXME: I hate this line.
      before_action :set_current_actor
      before_action :apply_localization_preferences
      before_action :set_color_theme # FIXME: I hate this line.
      before_action :enforce_withdrawal_gate! # FIXME: I hate this line.
      before_action :enforce_verification_if_required
      before_action :enforce_access_policy!
      before_action :set_current_observability
      prepend_around_action :with_actor_lifecycle

      # FIXME: Resolve the URL issues before deploying.
      protect_from_forgery using: :header_or_legacy_token,
                           trusted_origins: Jit::HostOriginEnv.trusted_origins(
                             ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
                           ),
                           with: :exception

      public

      def oidc_client_id
        "acme_app"
      end

      def oidc_sign_host
        ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
      end

      private
    end
  end
end
