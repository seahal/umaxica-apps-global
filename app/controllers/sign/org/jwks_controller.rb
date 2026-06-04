# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class JwksController < BareController
      include Authentication::JwksRendering

      AUTHENTICATION_MODE = :bare
      JWT_KEY_NAMESPACE = "SIGN_ORG"

      before_action :skip_jwks_session!
    end
  end
end
