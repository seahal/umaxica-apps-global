# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class TokensController < ApplicationController
      public_strict!

      # FIXME: This configuration disables CSRF protection by nullifying the session
      # instead of raising an exception on invalid/missing tokens. This is a potential
      # security vulnerability, but is kept because this OAuth/OIDC token endpoint
      # receives requests from third-party clients using client_id/client_secret
      # authentication, which cannot include CSRF tokens.
      # Consider implementing alternative security measures (e.g., origin validation,
      # rate limiting) to mitigate the risk.
      protect_from_forgery with: :null_session

      def create
        result = Oidc::TokenExchangeService.call(
          grant_type: params[:grant_type],
          code: params[:code],
          redirect_uri: params[:redirect_uri],
          client_id: params[:client_id],
          client_secret: params[:client_secret],
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
    end
  end
end
