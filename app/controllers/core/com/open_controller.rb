# typed: false
# frozen_string_literal: true

module Core
  module Com
    class OpenController < Apex::Com::OpenController
      def oidc_client_id = "core_com"

      def oidc_sign_host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    end
  end
end
