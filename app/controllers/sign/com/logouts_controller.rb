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
        sign_com_sign_out_completion_path(ri: ri)
      end
    end
  end
end
