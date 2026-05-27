# typed: false
# frozen_string_literal: true

module Core
  module Org
    class JwksController < BareController
      include Authentication::JwksRendering

      AUTHENTICATION_MODE = :bare
      JWT_KEY_NAMESPACE = "CORE_ORG"
    end
  end
end
