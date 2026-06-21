# typed: false
# frozen_string_literal: true

module Acme
  module Org
    module Sign
      class OutsController < Acme::Org::ApplicationController
        include ::AuthenticationLogoutable
        include ::SignOutNotice
        include ::SignOidcLogout

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        after_action :sign_out_notice_cache_headers!, only: %i(edit destroy)

        helper_method :sign_out_completed_description

        def new
          redirect_to(edit_acme_org_sign_out_path(ri: params[:ri]), status: :see_other)
        end

        def edit
          return render_oidc_logout_completion if sign_out_completion_notice_present?

          render "acme/shared/sign_outs/edit"
        end

        def destroy
          redirect_to(
            acme_org_oidc_logout_path(
              ri: params[:ri],
              id_token_hint: current_session_id_token_hint,
            ),
            status: :temporary_redirect,
            allow_other_host: false,
          )
        end

        private

        def current_session_id_token_hint
          OidcIdTokenIssuer.call(
            resource: current_resource,
            client: OidcClientRegistry.find!("base-rails-rp"),
            nonce: "sign-out",
            issuer: OidcIssuer.for_resource_type("operator"),
            jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("operator"),
            subject: OidcSubject.for(current_resource, resource_type: "operator"),
            sid: current_session_public_id,
          )
        end

        def oidc_logout_completion_template
          "acme/shared/sign_outs/show"
        end
      end
    end
  end
end
