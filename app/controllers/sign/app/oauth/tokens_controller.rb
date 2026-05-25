# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Oauth
      class TokensController < Sign::App::TokensController
        AUTHENTICATION_MODE = :open

      end
    end
  end
end
