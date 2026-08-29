# typed: false
# frozen_string_literal: true

module Base
  module App
    module Oauth
      class TokensController < ActionController::API
        include ActionController::MimeResponds
        include ::RateLimit
        include BaseOauthEndpoint
        include BaseOauthTokenEndpoint

        # The OAuth resource type this endpoint may redeem authorization codes for.
        # Surface isolation depends on this being stated here, not derived from the
        # class name, module name, request host, or a model name.
        OAUTH_RESOURCE_TYPE = "client"

        AUTHENTICATION_MODE = :open

        before_action :skip_oauth_session!
        after_action :set_oauth_cache_headers
        rate_limit(
          to: 10,
          within: 1.minute,
          by: -> { request.remote_ip },
          scope: "base_app_oauth_token",
          name: "token_exchange_ip",
          store: rate_limit_store,
          only: :create,
          with: -> {
            render_rate_limited(retry_after: 60)
          },
        )
      end
    end
  end
end
