# typed: false
# frozen_string_literal: true

module Acme
  module Com
    class JwksController < BareController
      include Authentication::JwksRendering

      AUTHENTICATION_MODE = :bare
      JWT_KEY_NAMESPACE = "ACME_COM"

      before_action :skip_jwks_session!
    end
  end
end
