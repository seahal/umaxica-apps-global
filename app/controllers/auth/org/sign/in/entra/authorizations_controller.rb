# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Sign
      module In
        module Entra
          # Starts the Microsoft Entra ID OIDC sign-in ceremony for operators.
          #
          # POST /sign/in/entra/authorization
          # Generates PKCE/state/nonce, stores only an opaque reference in the session, and
          # redirects the operator to the Entra authorization endpoint.
          class AuthorizationsController < ::Auth::Org::ApplicationController
            include MinimumResponseBudget
            include ExternalAuthenticationEndpoint

            AUTHENTICATION_MODE = :guest

            rate_limit(
              to: 10,
              within: 1.minute,
              by: -> { request.remote_ip },
              scope: "auth_org_sign_in_entra",
              name: "authorization_ip_burst",
              store: rate_limit_store,
              only: :create,
              with: -> {
                render_rate_limited(rule_name: "auth_org_sign_in_entra_authorization_ip_burst", retry_after: 60)
              },
            )

            before_action :start_minimum_response_budget, only: :create
            after_action :enforce_minimum_response_budget, only: :create

            def create
              unless external_authentication_allowed?(surface: "org", provider: "entra", operation: "login") &&
                  external_authentication_start_available?(provider: "entra", operation: "login", context: {})
                return render_entra_error(:provider_unavailable)
              end

              connection = active_connection_from_params
              return render_entra_error(:connection_not_found) if connection.nil?

              state         = SecureRandom.urlsafe_base64(32)
              nonce         = SecureRandom.urlsafe_base64(32)
              code_verifier = SecureRandom.urlsafe_base64(96)
              adapter = ExternalAuthentication::ProviderAdapterFactory.build(
                provider: "entra",
                connection: connection,
                redirect_uri: ExternalAuthenticationEntraRedirectUri.call,
              )
              reference = ExternalAuthenticationOrgEntraCeremonyStore.new.issue!(
                surface: "org",
                provider: "entra",
                operation: "login",
                connection_public_id: connection.public_id,
                state: state,
                nonce: nonce,
                code_verifier: code_verifier,
                return_target: signed_pt_param,
              )
              store_external_authentication_ceremony_reference(reference)

              redirect_to(
                adapter.authorization_url(
                  state: state,
                  nonce: nonce,
                  code_challenge: ExternalAuthentication::EntraProviderAdapter.pkce_s256_challenge(code_verifier),
                ),
                allow_other_host: true,
                status: :found,
              )
            end

            private

            def active_connection_from_params
              public_id = params.dig(:entra, :connection_public_id).to_s.strip
              return if public_id.blank?

              OrganizationEntraConnection.find_by(
                public_id: public_id,
                status_id: OrganizationEntraConnectionState::ACTIVE,
              )
            end

            def render_entra_error(reason)
              @error_reason = reason
              render "auth/org/sign/in/entras/new", status: :unprocessable_content, formats: :html
            end
          end
        end
      end
    end
  end
end
