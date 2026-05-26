# typed: false
# frozen_string_literal: true

module Core
  module App
    class OpenController < Apex::App::OpenController
      def oidc_client_id = "core_app"

      def oidc_sign_host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    end
  end
end
