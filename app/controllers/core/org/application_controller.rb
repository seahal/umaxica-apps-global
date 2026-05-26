# typed: false
# frozen_string_literal: true

module Core
  module Org
    class ApplicationController < Apex::Org::ApplicationController
      protect_from_forgery using: :header_or_legacy_token,
                           trusted_origins: HostOriginEnv.trusted_origins(
                             ENV.fetch("CORE_STAFF_URL", "jp.www.umaxica.org"),
                           ),
                           with: :exception

      def oidc_client_id
        "core_org"
      end

      def oidc_sign_host
        ENV.fetch("ID_STAFF_URL", "id.org.localhost")
      end
    end
  end
end
