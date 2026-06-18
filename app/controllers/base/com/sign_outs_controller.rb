# typed: false
# frozen_string_literal: true

module Base
  module Com
    class SignOutsController < Base::Com::BareController
      include ::AuthenticationClient
      include ::AuthenticationLogoutable

      AUTHENTICATION_MODE = :open

      before_action :authenticate!, only: :create

      def show
      end

      def create
        id_token_hint = current_session_id_token_hint
        logout_current_session!(reason: "user_logout")
        redirect_to(
          acme_com_oidc_logout_path(
            ri: params[:ri],
            id_token_hint: id_token_hint,
            post_logout_redirect_uri: base_com_root_url,
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

      def oidc_acme_host
        ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
      end
    end
  end
end
