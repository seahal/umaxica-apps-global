# typed: false
# frozen_string_literal: true

module Acme
  module App
    class JwksController < BareController
      include Authentication::JwksRendering

      AUTHENTICATION_MODE = :bare
      JWT_KEY_NAMESPACE = "ACME_APP"

      before_action :skip_jwks_session!
    end
  end
end
