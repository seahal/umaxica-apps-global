# typed: false
# frozen_string_literal: true

module Acme
  module App
    module Oidc
      class LogoutsController < Acme::App::ApplicationController
        include CommonRedirect
        include ::AuthenticationLogoutable
        include SignOutNotice
        include SignOidcLogout

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        helper_method :oidc_logout_confirmation_params
        helper_method :sign_out_completed_description

        def create
          show
        end

        private

        def oidc_logout_completed_path(ri:, sot: nil)
          complete_acme_app_sign_out_path(ri: ri)
        end
      end
    end
  end
end
