# typed: false
# frozen_string_literal: true

module Apex
  module Com
    class ApplicationController < ActionController::Base
      include ::RateLimit
      include ::Session
      include ::Preference::Global
      include ::Authentication::Visitor
      include ::Authorization::Visitor
      include ::Verification::Visitor
      include ActionPolicy::Controller
      include ::Oidc::SsoInitiator
      include ::CurrentSupport
      include ::Finisher

      allow_browser versions: :modern

      # NOTE: Order matters (dependencies rely on this sequence)
      # Layer order: RateLimit -> Preference -> AuthN(including AuthZ) -> Verification -> CurrentSupport
      before_action :check_default_rate_limit
      before_action :reset_flash
      prepend_before_action :set_preferences_cookie
      prepend_before_action :resolve_param_context
      prepend_before_action :set_region

      prepend_before_action :set_color_theme
      before_action :enforce_withdrawal_gate!
      before_action :transparent_refresh_access_token, unless: -> { request.format.json? }
      before_action :enforce_access_policy!
      before_action :enforce_verification_if_required
      before_action :set_current
      before_action :set_current_observability
      after_action :purge_current

      # NOTE: rewrite in production.
      # FIXME: Resolve the URL issues before deploying.
      protect_from_forgery using: :header_or_legacy_token,
                           trusted_origins: HostOriginEnv.trusted_origins(
                             ENV.fetch("APEX_CORPORATE_URL", "www.com.localhost"),
                           ),
                           with: :exception

      public_strict!

      public

      def oidc_client_id
        "apex_com"
      end

      def oidc_sign_host
        ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
      end

      def sign_in_url_with_return(return_to)
        decoded_return_to = decode_return_to(return_to)
        initiate_oidc_session!(decoded_return_to)
      end

      private

      def initiate_oidc_session!(return_to)
        code_verifier = SecureRandom.urlsafe_base64(32)
        code_challenge = Base64.urlsafe_encode64(
          Digest::SHA256.digest(code_verifier),
          padding: false,
        )
        state = SecureRandom.urlsafe_base64(24)

        session[:oidc_code_verifier] = code_verifier
        session[:oidc_state] = state
        session[:oidc_return_to] = return_to

        oidc_authorize_url(code_challenge, state)
      end

      def decode_return_to(return_to)
        Base64.urlsafe_decode64(return_to.to_s)
      rescue ArgumentError
        "/"
      end
    end
  end
end
