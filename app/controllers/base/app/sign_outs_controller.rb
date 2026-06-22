# typed: false
# frozen_string_literal: true

module Base
  module App
    class SignOutsController < Base::App::BareController
      include ::AuthenticationClient
      include ::AuthenticationLogoutable
      include ::SignOutNotice
      include ::OidcRpLogoutLauncher

      AUTHENTICATION_MODE = :open
      skip_before_action :transparent_refresh_access_token, raise: false

      before_action :authenticate!, only: :create
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
          client_id: "base-rails-rp",
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
    end
  end
end
