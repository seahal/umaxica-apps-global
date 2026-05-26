# typed: false
# frozen_string_literal: true

module Core
  module App
    class ApplicationController < Apex::App::ApplicationController
      protect_from_forgery using: :header_or_legacy_token,
                           trusted_origins: HostOriginEnv.trusted_origins(
                             ENV.fetch("CORE_SERVICE_URL", "jp.www.umaxica.app"),
                           ),
                           with: :exception

      def oidc_client_id
        "core_app"
      end

      def oidc_sign_host
        ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
      end
    end
  end
end
