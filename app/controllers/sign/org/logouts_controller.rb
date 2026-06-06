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
        sign_org_sign_out_completion_path(ri: ri)
      end
    end
  end
end
