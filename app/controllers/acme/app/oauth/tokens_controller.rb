# typed: false
# frozen_string_literal: true

module Acme
  module App
    module Oauth
      class TokensController < Acme::App::BareController
        include Acme::OauthTokenEndpoint
      end
    end
  end
end
