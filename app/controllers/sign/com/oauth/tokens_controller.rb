# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Oauth
      class TokensController < ::Sign::Com::TokensController
        AUTHENTICATION_MODE = :open
      end
    end
  end
end
