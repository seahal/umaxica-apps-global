# typed: false
# frozen_string_literal: true

module Acme
  module Com
    module Sign
      class OutsController < Acme::Com::ApplicationController
        include ::AuthenticationLogoutable
        include ::SignOutNotice
        include ::SignOidcLogout

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
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
          if current_resource.blank? && current_session_public_id.blank?
            return render_oidc_logout_completion
          end

          prepare_sign_out_completion_notice!
          logout_current_session!(reason: "user_logout")
          issue_sign_out_notice!
          redirect_to(sign_out_complete_path, status: :see_other)
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
      end
    end
  end
end
