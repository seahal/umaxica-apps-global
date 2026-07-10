# typed: false
# frozen_string_literal: true

module Base
  module App
    module Oauth
      class JwksController < BareController
        include AuthenticationJwksRendering

        AUTHENTICATION_MODE = :bare
        JWT_KEY_NAMESPACE = "BASE_APP"

        before_action :skip_jwks_session!
      end
    end
  end
end
