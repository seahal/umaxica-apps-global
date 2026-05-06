# typed: false
# frozen_string_literal: true

module Sign
  module App
    class TokensController < ApplicationController
      include ::RateLimit

      public_strict!
      # Token endpoints used by OIDC clients cannot provide CSRF tokens.
      # We use null_session to ensure no session access occurs during the request.
      protect_from_forgery with: :null_session

      # Limit token exchange attempts to prevent brute-force/DoS
      rate_limit to: 10, within: 1.minute, only: :create

      def create
        result = Oidc::TokenExchangeService.call(
          grant_type: params[:grant_type],
          code: params[:code],
          redirect_uri: params[:redirect_uri],
          client_id: params[:client_id],
          client_secret: params[:client_secret],
          code_verifier: params[:code_verifier],
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
    end
  end
end
