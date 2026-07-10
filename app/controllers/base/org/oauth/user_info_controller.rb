# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Oauth
      class UserInfoController < Base::Org::BareController
        include BaseOauthEndpoint

        AUTHENTICATION_MODE = :open

        before_action :skip_oauth_session!
        after_action :set_oauth_cache_headers

        def show
          result = ::OidcAccessTokenAuthenticator.call(
            access_token: ::AuthAuthorizationHeader.access_token(request),
            resource_type: "operator",
            host: request.host,
            authorization_scheme: ::AuthAuthorizationHeader.scheme(request),
            dpop_proof: request.headers["DPoP"],
            request_method: request.request_method,
            request_uri: request.original_url,
          )
          return render json: { error: result.error }, status: :unauthorized unless result.success?

          render json: ::OidcUserInfoResponse.build(resource: result.resource, payload: result.payload)
        end
      end
    end
  end
end
