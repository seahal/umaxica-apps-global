# typed: false
# frozen_string_literal: true

module Core
  module Com
    class JwksController < BareController
      include Authentication::JwksRendering

      AUTHENTICATION_MODE = :bare
      JWT_KEY_NAMESPACE = "CORE_COM"
    end
  end
end
