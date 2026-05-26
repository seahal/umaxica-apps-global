# typed: false
# frozen_string_literal: true

module Sign
  module Org
    module Oauth
      class AuthorizationsController < Sign::Org::AuthorizesController
        AUTHENTICATION_MODE = :private
      end
    end
  end
end
