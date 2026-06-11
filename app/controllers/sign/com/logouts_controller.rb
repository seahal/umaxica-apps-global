# typed: false
# frozen_string_literal: true

module Sign
  module Com
    class LogoutsController < ::Sign::Com::ApplicationController
      include CommonRedirect
      include SignOutNotice
      include SignOidcLogout

      AUTHENTICATION_MODE = :open
      declare_authentication_mode! :open
      helper_method :sign_out_completed_description

      private

      def oidc_logout_completed_path(ri:)
        acme_com_sign_out_path(ri: ri, host: ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost"))
      end
    end
  end
end
