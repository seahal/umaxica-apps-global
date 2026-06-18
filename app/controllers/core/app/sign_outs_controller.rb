# typed: false
# frozen_string_literal: true

module Core
  module App
    class SignOutsController < Core::App::ApplicationController
      include ::AuthenticationLogoutable

      AUTHENTICATION_MODE = :open
      declare_authentication_mode! :open

      before_action :authenticate!, only: :create

      def show
      end

      def create
        id_token_hint = current_session_id_token_hint
        logout_current_session!(reason: "user_logout")
        redirect_to(
          acme_app_oidc_logout_url(
            host: oidc_acme_host,
            ri: params[:ri],
            id_token_hint: id_token_hint,
            post_logout_redirect_uri: core_app_root_url,
          ),
          status: :temporary_redirect,
          allow_other_host: false,
        )
      end

      private

      def current_session_id_token_hint
        OidcIdTokenIssuer.call(
          resource: current_resource,
          client: OidcClientRegistry.find!("core-next-rp"),
          nonce: "sign-out",
          issuer: OidcIssuer.for_resource_type("client"),
          jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"),
          subject: OidcSubject.for(current_resource, resource_type: "client"),
          sid: current_session_public_id,
        )
      end
    end
  end
end
