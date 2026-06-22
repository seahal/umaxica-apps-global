# typed: false
# frozen_string_literal: true

module Sign
  module App
    module Sign
      class OutsController < ::Sign::App::ApplicationController
        include ::AuthenticationLogoutable
        include ::SignOutNotice
        include ::OidcRpLogoutLauncher

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        skip_before_action :transparent_refresh_access_token, raise: false
        helper_method :sign_out_completed_description
        helper_method :sign_out_confirmation_form_path

        after_action :sign_out_notice_cache_headers!, only: %i(edit complete)

        def new
          redirect_to(sign_out_edit_path, status: :see_other)
        end

        def edit
          render "sign/shared/sign_outs/edit"
        end

        def create
          return continue_acme_coordinated_logout if params[:logout_challenge].present?

          launch_oidc_rp_logout!(
            client_id: "sign-rp",
            issuer_resource_type: "client",
            token_issuer: "client",
          )
        end

        def complete
          complete_oidc_rp_logout!
        end

        private

        def sign_out_confirmation_form_path
          sign_out_post_path
        end

        def continue_acme_coordinated_logout
          transaction = AcmeLogoutTransactionService.find_by_logout_challenge!(params.expect(:logout_challenge))
          return render_oidc_rp_logout_completion if transaction.expired?

          logout_current_session!(reason: "user_logout")
          issue_sign_out_notice!

          AcmeLogoutTransactionService.advance!(
            logout_challenge: transaction.logout_challenge,
            step: "sign_cleared",
          )

          redirect_to_jump_url(
            acme_oidc_logout_url(logout_challenge: transaction.logout_challenge),
            status: :see_other,
          )
        rescue ActiveRecord::RecordNotFound
          render_oidc_rp_logout_completion
        rescue ArgumentError
          render_oidc_rp_logout_completion
        end
      end
    end
  end
end
