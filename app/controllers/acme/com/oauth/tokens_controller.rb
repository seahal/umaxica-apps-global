# typed: false
# frozen_string_literal: true

module Acme
  module Com
    module Oauth
      class TokensController < Acme::Com::BareController
        include ::RateLimit
        include Acme::OauthEndpoint
        include Acme::OauthTokenEndpoint

        AUTHENTICATION_MODE = :open

        before_action :skip_oauth_session!
        after_action :set_oauth_cache_headers
        rate_limit to: 10, within: 1.minute, only: :create
      end
    end
  end
end
