# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Oauth
      class AuthorizationsController < Sign::Com::AuthorizesController
        AUTHENTICATION_MODE = :private
      end
    end
  end
end
