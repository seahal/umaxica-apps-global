# typed: false
# frozen_string_literal: true

module Base
  module App
    module Oidc
      class LogoutsController < Base::App::ApplicationController
        include CommonRedirect
        include ::AuthenticationLogoutable
        include SignOutNotice
        include SignOidcLogout

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        COORDINATED_LOGOUT_TRUSTED_ORIGINS = JitHostOriginEnv.trusted_origins(
          ENV.fetch("PUBLIC_AUTH_SERVICE_URL", ENV.fetch("AUTH_SERVICE_URL", "auth.app.localhost")),
          ENV.fetch("PUBLIC_CORE_SERVICE_URL", ENV.fetch("CORE_SERVICE_URL", "jpx.umaxica.app")),
          ENV.fetch("PUBLIC_BASE_SERVICE_URL", ENV.fetch("BASE_SERVICE_URL", "www-jp.umaxica.app")),
          ENV.fetch("PRIVATE_PALM_SERVICE_URL", ENV.fetch("PALM_SERVICE_URL", "palm.app.localhost")),
        ).freeze

        protect_from_forgery using: :header_only,
                             trusted_origins: COORDINATED_LOGOUT_TRUSTED_ORIGINS,
                             with: :exception,
                             only: :create,
                             if: -> { params[:logout_challenge].present? }
        skip_before_action :transparent_refresh_access_token, raise: false
        before_action only: :create do
          verify_coordinated_sign_out_post!(trusted_origins: COORDINATED_LOGOUT_TRUSTED_ORIGINS)
        end
        helper_method :oidc_logout_confirmation_params
        helper_method :sign_out_completed_description

        def create
          show
        end

        private

        def oidc_logout_completed_path(ri:, _sot: nil)
          complete_base_app_sign_out_path(ri: ri)
        end
      end
    end
  end
end
