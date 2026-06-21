# typed: false
# frozen_string_literal: true

module Sign
  module Com
    module Sign
      class OutsController < ::Sign::Com::ApplicationController
        include ::AuthenticationLogoutable
        include ::SignOutNotice
        include ::OidcRpLogoutLauncher

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
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
          launch_oidc_rp_logout!(
            client_id: "sign-rp",
            issuer_resource_type: "visitor",
            token_issuer: "visitor",
          )
        end

        def complete
          complete_oidc_rp_logout!
        end

        private

        def sign_out_confirmation_form_path
          sign_out_post_path
        end
      end
    end
  end
end
