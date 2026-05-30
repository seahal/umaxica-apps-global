# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class LogoutsController < Sign::Org::ApplicationController
      include Sign::OidcLogout

      AUTHENTICATION_MODE = :open

      private

      def oidc_logout_completed_path(ri:)
        sign_org_sign_out_path(ri: ri)
      end
    end
  end
end
