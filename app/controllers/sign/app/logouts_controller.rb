# typed: false
# frozen_string_literal: true

module Sign
  module App
    class LogoutsController < Sign::App::ApplicationController
      include Common::Redirect
      include Sign::OutNotice
      include Sign::OidcLogout

      AUTHENTICATION_MODE = :open
      declare_authentication_mode! :open
      helper_method :sign_out_completed_description

      private

      def oidc_logout_completed_path(ri:)
        sign_app_sign_out_path(ri: ri)
      end
    end
  end
end
