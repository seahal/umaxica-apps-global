# typed: false
# frozen_string_literal: true

module Acme
  module Com
    module Oauth
      class JwksController < BareController
        include AuthenticationJwksRendering

        AUTHENTICATION_MODE = :bare
        JWT_KEY_NAMESPACE = "ACME_COM"

        before_action :skip_jwks_session!
      end
    end
  end
end
