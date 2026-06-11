# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class LogoutsController < ::Sign::Org::ApplicationController
      include CommonRedirect
      include SignOutNotice
      include SignOidcLogout

      AUTHENTICATION_MODE = :open
      declare_authentication_mode! :open
      helper_method :sign_out_completed_description

      private

      def oidc_logout_completed_path(ri:)
        acme_org_sign_out_path(ri: ri, host: ENV.fetch("ACME_STAFF_URL", "www.org.localhost"))
      end
    end
  end
end
