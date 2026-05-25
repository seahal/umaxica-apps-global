# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class LogoutsController < OpenController
      AUTHENTICATION_MODE = :open

      include Sign::OidcLogout

      private

      def oidc_logout_completed_path(ri:)
        sign_org_out_path(ri: ri)
      end
    end
  end
end
