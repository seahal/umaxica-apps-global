# typed: false
# frozen_string_literal: true

module Acme
  module Com
    module Oidc
      class LogoutsController < Acme::Com::ApplicationController
        include Common::Redirect
        include Sign::OutNotice
        include Sign::OidcLogout

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        helper_method :sign_out_completed_description

        private

        def oidc_logout_completed_path(ri:)
          acme_com_sign_out_path(ri: ri)
        end
      end
    end
  end
end
