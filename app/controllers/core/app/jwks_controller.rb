# typed: false
# frozen_string_literal: true

module Core
  module App
    class JwksController < BareController
      include Authentication::JwksRendering

      AUTHENTICATION_MODE = :bare
      JWT_KEY_NAMESPACE = "CORE_APP"

      before_action :skip_jwks_session!
    end
  end
end
