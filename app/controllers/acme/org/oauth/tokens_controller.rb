# typed: false
# frozen_string_literal: true

module Acme
  module Org
    module Oauth
      class TokensController < Acme::Org::BareController
        include ::RateLimit
        include AcmeOauthEndpoint
        include AcmeOauthTokenEndpoint

        AUTHENTICATION_MODE = :open

        before_action :skip_oauth_session!
        after_action :set_oauth_cache_headers
        rate_limit(
          to: 10,
          within: 1.minute,
          by: -> { request.remote_ip },
          scope: "acme_org_oauth_token",
          name: "token_exchange_ip",
          store: rate_limit_store,
          only: :create,
          with: -> {
            render_rate_limited(
              rule_name: "acme_org_oauth_token_exchange_ip",
              retry_after: 60,
            )
          },
        )
      end
    end
  end
end
