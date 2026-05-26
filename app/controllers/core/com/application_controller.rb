# typed: false
# frozen_string_literal: true

module Core
  module Com
    class ApplicationController < Apex::Com::ApplicationController
      protect_from_forgery using: :header_or_legacy_token,
                           trusted_origins: HostOriginEnv.trusted_origins(
                             ENV.fetch("CORE_CORPORATE_URL", "www.jp.umaxica.com"),
                           ),
                           with: :exception

      def oidc_client_id
        "core_com"
      end

      def oidc_sign_host
        ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
      end
    end
  end
end
