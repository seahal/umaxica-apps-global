# typed: false
# frozen_string_literal: true

module Base
  module App
    module Oauth
      class UserinfosController < Base::App::BareController
        include BaseOauthEndpoint

        AUTHENTICATION_MODE = :open

        before_action :skip_oauth_session!
        after_action :set_oauth_cache_headers
        # Bearer-token probing against a resource endpoint must be bounded, as it
        # already is on the token endpoint.
        rate_limit(
          to: 60,
          within: 1.minute,
          by: -> { request.remote_ip },
          scope: "base_app_oauth_userinfo",
          name: "userinfo_ip",
          store: rate_limit_store,
          only: :show,
          with: -> {
            render_rate_limited(retry_after: 60)
          },
        )

        def show
          result = ::OidcAccessTokenAuthenticator.call(
            access_token: ::AuthAuthorizationHeader.access_token(request),
            resource_type: "client",
            host: request.host,
            authorization_scheme: ::AuthAuthorizationHeader.scheme(request),
            dpop_proof: request.headers["DPoP"],
            request_method: request.request_method,
            request_uri: request.original_url,
          )
          return render_oauth_bearer_error(result.error) unless result.success?

          render json: ::OidcUserInfoResponseSerializer.build(resource: result.resource, payload: result.payload)
        end
      end
    end
  end
end
