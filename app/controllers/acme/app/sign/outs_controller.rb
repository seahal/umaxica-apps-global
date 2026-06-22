# typed: false
# frozen_string_literal: true

module Acme
  module App
    module Sign
      class OutsController < Acme::App::ApplicationController
        include ::AuthenticationLogoutable
        include ::SignOutNotice
        include ::SignOidcLogout

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        skip_before_action :transparent_refresh_access_token, raise: false
        after_action :sign_out_notice_cache_headers!, only: %i(edit complete)

        helper_method :sign_out_completed_description
        helper_method :sign_out_confirmation_form_path

        def new
          redirect_to(sign_out_edit_path, status: :see_other)
        end

        def edit
          render "acme/shared/sign_outs/edit"
        end

        def create
          return render_oidc_logout_completion if logout_browser_session_missing?

          transaction_result = AcmeLogoutTransactionService.issue!(
            origin_surface: "acme",
            initiating_client_id: "acme-rp",
            completion_url: AcmeLogoutTransactionService.completion_url_for(
              origin_surface: "acme",
              ri: params[:ri],
              surface: sign_surface_name,
            ),
            actor_ref: current_resource.try(:public_id),
            session_ref: safe_current_session_public_id_for_logout,
            callback_state: nil,
            surface: sign_surface_name,
          )
          return render_oidc_logout_completion unless transaction_result.success?

          transaction = transaction_result.transaction
          prepare_sign_out_completion_notice!
          logout_current_session!(reason: "user_logout")
          issue_sign_out_notice!
          AcmeLogoutTransactionService.advance!(logout_challenge: transaction.logout_challenge, step: "origin_cleared")

          redirect_to_jump_url(
            edit_sign_app_sign_out_url(
              host: Rails.configuration.x.boot_config.fetch(:hosts).sign_service.host,
              ri: params[:ri],
              logout_challenge: transaction.logout_challenge,
              protocol: "https",
            ),
            status: :see_other,
          )
        end

        def complete
          render_oidc_logout_completion
        end

        private

        def sign_out_confirmation_form_path
          sign_out_post_path
        end

        def oidc_logout_completion_template
          "acme/shared/sign_outs/complete"
        end

        def logout_browser_session_missing?
          request.headers["Authorization"].blank? &&
            cookies[AuthenticationBase::REFRESH_COOKIE_KEY].blank?
        end
      end
    end
  end
end
