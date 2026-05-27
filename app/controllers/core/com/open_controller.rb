# typed: false
# frozen_string_literal: true

module Core
  module Com
    class OpenController < ApplicationController
      AUTHENTICATION_MODE = :open

      declare_authentication_mode! :open

      layout false

      def oidc_client_id = "core_com"

      def oidc_sign_host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    end
  end
end
