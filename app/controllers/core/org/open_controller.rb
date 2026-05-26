# typed: false
# frozen_string_literal: true

module Core
  module Org
    class OpenController < Apex::Org::OpenController
      def oidc_client_id = "core_org"

      def oidc_sign_host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    end
  end
end
