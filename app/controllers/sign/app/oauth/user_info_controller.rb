# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Oauth
      class UserInfoController < BaseController
        AUTHENTICATION_MODE = :open

        def show
          # Compatibility endpoint only. acme/www owns userinfo authority.
          result = ::Oidc::AccessTokenAuthenticator.call(
            access_token: ::Auth::AuthorizationHeader.access_token(request),
            resource_type: "client",
            host: request.host,
            authorization_scheme: ::Auth::AuthorizationHeader.scheme(request),
            dpop_proof: request.headers["DPoP"],
            request_method: request.request_method,
            request_uri: request.original_url,
          )
          return render json: { error: result.error }, status: :unauthorized unless result.success?

          render json: ::Oidc::UserInfoResponse.build(resource: result.resource, payload: result.payload)
        end
      end
    end
  end
end
