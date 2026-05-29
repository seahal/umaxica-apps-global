# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Oauth
      class RevocationsController < BaseController
        AUTHENTICATION_MODE = :open

        def create
          result = Oidc::TokenRevocationService.call(
            token: params[:token],
            client_id: params[:client_id],
            client_secret: params[:client_secret],
            token_type_hint: params[:token_type_hint],
            host: request.host,
          )
          return head :ok if result.success?

          render json: { error: result.error, error_description: result.error_description },
                 status: :unauthorized
        end
      end
    end
  end
end
