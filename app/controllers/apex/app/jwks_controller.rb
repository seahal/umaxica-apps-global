# typed: false
# frozen_string_literal: true

module Apex
  module App
    class JwksController < BareController
      include Authentication::JwksRendering

      AUTHENTICATION_MODE = :bare
      JWT_KEY_NAMESPACE = "ACME_APP"
    end
  end
end
