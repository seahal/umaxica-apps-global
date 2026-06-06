# typed: false
# frozen_string_literal: true

module Acme
  module App
    module Oauth
      class AuthorizationsController < Acme::App::ApplicationController
        AUTHENTICATION_MODE = :private

        before_action :authenticate!

        def show
          access_claims = Actor.authn.access_claims
          amr = access_claims&.dig("amr")
          result = ::OidcAuthorizeService.call(
            params: authorize_params,
            resource: current_client,
            auth_method: Array(amr).first,
            acr: access_claims&.dig("acr"),
          )

          if result.success?
            redirect_to_jump_url(result.redirect_url)
          else
            render json: { error: result.error, error_description: result.error_description },
                   status: :bad_request
          end
        end

        private

        def authorize_params
          params.permit(
            :response_type, :client_id, :redirect_uri, :state,
            :code_challenge, :code_challenge_method, :scope, :nonce,
          )
        end
      end
    end
  end
end
