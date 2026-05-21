# typed: false
# frozen_string_literal: true

module Sign
  module Com
    class LogoutsController < OpenController
      include Sign::OidcLogout

      private

      def oidc_logout_completed_path(ri:)
        sign_com_out_path(ri: ri)
      end
    end
  end
end
