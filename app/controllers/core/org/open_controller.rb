# typed: false
# frozen_string_literal: true

module Core
  module Org
    class OpenController < ApplicationController
      AUTHENTICATION_MODE = :open

      declare_authentication_mode! :open

      layout false

      def oidc_client_id = "core_org"

      def oidc_sign_host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    end
  end
end
