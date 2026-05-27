# typed: false
# frozen_string_literal: true

module Sign
  module Com
    class JwksController < BareController
      include Authentication::JwksRendering

      AUTHENTICATION_MODE = :bare
      JWT_KEY_NAMESPACE = "SIGN_COM"
    end
  end
end
