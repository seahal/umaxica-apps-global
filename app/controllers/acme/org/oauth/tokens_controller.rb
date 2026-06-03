# typed: false
# frozen_string_literal: true

module Acme
  module Org
    module Oauth
      class TokensController < Acme::Org::BareController
        include Acme::OauthTokenEndpoint
      end
    end
  end
end
