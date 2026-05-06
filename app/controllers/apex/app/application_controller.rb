# typed: false
# frozen_string_literal: true

module Apex
  module App
    class ApplicationController < ActionController::Base
      include ::RateLimit
      include ::Session
      include ::Preference::Global
      include ::Preference::Adoption # FIXME: I hate this line.
      include ::Authentication::User
      include ::Authorization::User
      include ::Verification::User
      include ActionPolicy::Controller # FIXME: I hate this line.
      include ::Oidc::SsoInitiator # FIXME: I hate this line.
      include ::CurrentSupport
      include ::Finisher

      allow_browser versions: :modern

      # NOTE: Order matters (dependencies rely on this sequence)
      # Layer order: RateLimit -> Preference -> AuthN(including AuthZ) -> Verification -> CurrentSupport -> O11y
      before_action :check_default_rate_limit
      before_action :reset_flash
      prepend_before_action :set_preferences_cookie # FIXME: I hate this line.
      prepend_before_action :resolve_param_context # FIXME: I hate this line.
      prepend_before_action :set_region # FIXME: I hate this line.
      prepend_before_action :set_locale # FIXME: I hate this line.
      prepend_before_action :set_timezone # FIXME: I hate this line.

      prepend_before_action :set_color_theme # FIXME: I hate this line.
      before_action :enforce_withdrawal_gate! # FIXME: I hate this line.
      before_action :transparent_refresh_access_token, unless: -> { request.format.json? } # FIXME: I hate this line.
      before_action :enforce_access_policy!
      before_action :enforce_verification_if_required
      before_action :set_current
      before_action :set_current_observability
      after_action :purge_current

      # FIXME: Resolve the URL issues before deploying.
      protect_from_forgery using: :header_or_legacy_token,
                           trusted_origins: HostOriginEnv.trusted_origins(
                             ENV.fetch("APEX_SERVICE_URL", "www.app.localhost"),
                           ),
                           with: :exception

      public_strict!

      public

      def oidc_client_id
        "apex_app"
      end

      def oidc_sign_host
        ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
      end

      private
    end
  end
end
