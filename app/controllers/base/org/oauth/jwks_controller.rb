# typed: false
# frozen_string_literal: true

module Base
  module Org
    module Oauth
      class JwksController < BareController
        include AuthenticationJwksRendering

        AUTHENTICATION_MODE = :bare
        JWT_KEY_NAMESPACE = "BASE_ORG"

        before_action :skip_jwks_session!
      end
    end
  end
end
