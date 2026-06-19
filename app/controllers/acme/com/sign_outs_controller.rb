# typed: false
# frozen_string_literal: true

module Acme
  module Com
    class SignOutsController < Acme::Com::ApplicationController
      include ::AuthenticationLogoutable
      include ::SignOutNotice
      include ::SignOidcLogout

      AUTHENTICATION_MODE = :open
      declare_authentication_mode! :open

      before_action :authenticate!, only: %i(show create)
      helper_method :sign_out_completed_description

      def show
        render "acme/shared/sign_outs/show"
      end

      def create
        redirect_to(
          acme_com_oidc_logout_path(
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
          issuer: OidcIssuer.for_resource_type("visitor"),
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("visitor"),
          subject: OidcSubject.for(current_resource, resource_type: "visitor"),
          sid: current_session_public_id,
        )
      end
    end
  end
end
