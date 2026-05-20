# typed: false
# frozen_string_literal: true

module Sign
  module Org
    class LogoutsController < OpenController
      include Sign::OidcLogout

      private

      def oidc_logout_completed_path(ri:)
        sign_org_signed_out_path(ri: ri)
      end
    end
  end
end
