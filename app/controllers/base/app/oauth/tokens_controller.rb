# typed: false
# frozen_string_literal: true

module Base
  module App
    module Oauth
      class TokensController < Base::App::BareController
        include ::RateLimit
        include BaseOauthEndpoint
        include BaseOauthTokenEndpoint

        AUTHENTICATION_MODE = :open

        protect_from_forgery using: :header_or_legacy_token,
                             trusted_origins: Base::App::Oauth::ProtocolController::TRUSTED_BROWSER_ORIGINS,
                             with: :null_session

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
            render_rate_limited(
              rule_name: "base_app_oauth_token_exchange_ip",
              retry_after: 60,
            )
          },
        )
      end
    end
  end
end
