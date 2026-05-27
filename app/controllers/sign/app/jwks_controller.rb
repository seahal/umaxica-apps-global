# typed: false
# frozen_string_literal: true

module Sign
  module App
    class JwksController < BareController
      include Authentication::JwksRendering

      AUTHENTICATION_MODE = :bare
      JWT_KEY_NAMESPACE = "SIGN_APP"
    end
  end
end
