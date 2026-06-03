# typed: false
# frozen_string_literal: true

module Acme
  module Com
    module Oauth
      class TokensController < Acme::Com::BareController
        include Acme::OauthTokenEndpoint
      end
    end
  end
end
