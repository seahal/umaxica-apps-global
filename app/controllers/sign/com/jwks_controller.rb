# typed: false
# frozen_string_literal: true

module Sign
  module Com
    class JwksController < BareController
      include AuthenticationJwksRendering

      AUTHENTICATION_MODE = :bare
      JWT_KEY_NAMESPACE = "SIGN_COM"

      before_action :skip_jwks_session!
    end
  end
end
