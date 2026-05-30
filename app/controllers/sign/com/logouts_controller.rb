# typed: false
# frozen_string_literal: true

module Sign
  module Com
    class LogoutsController < Sign::Com::ApplicationController
      include Sign::OidcLogout

      AUTHENTICATION_MODE = :open

      private

      def oidc_logout_completed_path(ri:)
        sign_com_sign_out_path(ri: ri)
      end
    end
  end
end
