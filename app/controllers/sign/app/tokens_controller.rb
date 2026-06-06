# typed: false
# frozen_string_literal: true

module Sign
  module App
    class TokensController < ApplicationController
      include ::RateLimit

      AUTHENTICATION_MODE = :deny_all

      declare_authentication_mode! :open

      prepend_before_action :skip_compatibility_session_cookie, only: :create
      protect_from_forgery with: :null_session, only: :create
      skip_before_action :reset_flash, raise: false
      skip_before_action :transparent_refresh_access_token
      skip_before_action :set_region, raise: false
      skip_before_action :set_preferences_cookie, raise: false
      skip_before_action :apply_localization_preferences, raise: false
      skip_before_action :set_locale, raise: false
      skip_before_action :set_color_theme, raise: false

      # Limit token exchange attempts to prevent brute-force/DoS
      rate_limit to: 10, within: 1.minute, only: :create

      def create
        # Compatibility endpoint only. acme/www owns token issuance.
        result = ::Oidc::TokenExchangeService.call(
          grant_type: params[:grant_type],
          code: params[:code],
          redirect_uri: params[:redirect_uri],
          client_id: params[:client_id],
          client_secret: params[:client_secret],
          client_assertion_type: params[:client_assertion_type],
          client_assertion: params[:client_assertion],
          code_verifier: params[:code_verifier],
          dpop_proof: request.headers["DPoP"],
          token_endpoint_uri: request.original_url,
          request_method: request.request_method,
        )

        if result.success?
          response.headers["Cache-Control"] = "no-store"
          response.headers["Pragma"] = "no-cache"
          render json: result.token_response, status: :ok
        else
          render json: { error: result.error, error_description: result.error_description },
                 status: :bad_request
        end
      end

      private

      def skip_compatibility_session_cookie
        request.session_options[:skip] = true
      end
    end
  end
end
