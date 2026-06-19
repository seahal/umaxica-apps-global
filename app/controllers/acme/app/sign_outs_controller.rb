# typed: false
# frozen_string_literal: true

module Acme
  module App
    class SignOutsController < Acme::App::ApplicationController
      include ::AuthenticationLogoutable
      include ::SignOutNotice
      include ::SignOidcLogout

      AUTHENTICATION_MODE = :open
      declare_authentication_mode! :open

      helper_method :sign_out_completed_description

      def show
        render "acme/shared/sign_outs/show"
      end

      def create
        redirect_to(
          acme_app_oidc_logout_url(
            host: oidc_acme_host,
            ri: params[:ri],
            id_token_hint: current_session_id_token_hint,
          ),
          status: :temporary_redirect,
          allow_other_host: false,
        )
      end

      private

      def current_session_id_token_hint
        return if current_resource.blank? || current_session_public_id.blank?

        OidcIdTokenIssuer.call(
          resource: current_resource,
          client: OidcClientRegistry.find!("base-rails-rp"),
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
