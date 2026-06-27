# typed: false
# frozen_string_literal: true

module Base
  module App
    module Sign
      class OutsController < Base::App::ApplicationController
        include ::AuthenticationLogoutable
        include ::SignOutNotice

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open

        after_action :sign_out_notice_cache_headers!, only: %i(new complete)

        def new
          render "base/shared/sign_outs/edit"
        end

        def create
          if current_resource.blank? && current_session_public_id.blank?
            return redirect_to(
              complete_base_app_sign_out_url(
                host: Rails.configuration.x.boot_config.fetch(:hosts).base_service.host,
                protocol: "https",
              ),
              status: :see_other,
              allow_other_host: true,
            )
          end

          logout_current_session!(reason: "user_logout")
          _transaction, raw_token = LogoutTransaction.issue!(
            issuer: "base",
            audience: "sign_app",
            purpose: "sign_out",
            expires_in: 2.minutes,
          )

          redirect_to(
            base_app_sign_out_url(
              host: Rails.configuration.x.boot_config.fetch(:hosts).sign_service.host,
              protocol: "https",
              logout_token: raw_token,
            ),
            status: :see_other,
            allow_other_host: true,
          )
        end

        def complete
          render "base/shared/sign_outs/complete"
        end
      end
    end
  end
end
