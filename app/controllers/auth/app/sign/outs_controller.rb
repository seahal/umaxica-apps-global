# typed: false
# frozen_string_literal: true

module Auth
  module App
    module Sign
      class OutsController < ::Auth::App::ApplicationController
        include ::AuthenticationLogoutable
        include ::SignOutNotice

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        skip_before_action :set_region, only: %i(new edit create destroy)

        after_action :sign_out_notice_cache_headers!, only: %i(create)

        def new
          redirect_to(
            new_acme_app_sign_out_url(
              host: Rails.configuration.x.boot_config.fetch(:hosts).acme_service.host,
              protocol: "https",
            ),
            status: :see_other,
            allow_other_host: true,
          )
        end

        def edit
          redirect_to(
            new_acme_app_sign_out_url(
              host: Rails.configuration.x.boot_config.fetch(:hosts).acme_service.host,
              protocol: "https",
            ),
            status: :see_other,
            allow_other_host: true,
          )
        end

        def create
          LogoutTransaction.consume_one_time_url_token!(
            raw_token: params[:logout_token],
            issuer: "acme",
            audience: "sign_app",
            purpose: "sign_out",
          )

          clear_sign_cleanup_state!

          redirect_to(
            complete_acme_app_sign_out_url(
              host: Rails.configuration.x.boot_config.fetch(:hosts).acme_service.host,
              protocol: "https",
            ),
            status: :see_other,
            allow_other_host: true,
          )
        end

        def destroy
          redirect_to(
            new_acme_app_sign_out_url(
              host: Rails.configuration.x.boot_config.fetch(:hosts).acme_service.host,
              protocol: "https",
            ),
            status: :see_other,
            allow_other_host: true,
          )
        end

        private

        def clear_sign_cleanup_state!
          cookies.delete(AuthenticationBase::REFRESH_COOKIE_KEY)
          logout_current_session!(reason: "user_logout")
        end
      end
    end
  end
end
