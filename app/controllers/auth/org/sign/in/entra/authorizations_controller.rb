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
          # Generates PKCE/state/nonce, stores them in the session, and
          # redirects the operator to the Entra authorization endpoint.
          # Shared ceremony invariants live in OrgEntraCeremony.
          class AuthorizationsController < ::Auth::Org::ApplicationController
            include MinimumResponseBudget
            include OrgEntraCeremony

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
              connection = find_active_connection_from_params
              return render_entra_error(:connection_not_found) if connection.nil?

              state         = SecureRandom.urlsafe_base64(32)
              nonce         = SecureRandom.urlsafe_base64(32)
              code_verifier = SecureRandom.urlsafe_base64(96)
              code_challenge = pkce_s256_challenge(code_verifier)

              session[:entra_state]               = state
              session[:entra_nonce]               = nonce
              session[:entra_code_verifier]       = code_verifier
              session[:entra_connection_public_id] = connection.public_id
              session[:entra_pt] = signed_pt_param

              redirect_to(
                build_entra_authorization_url(
                  connection: connection,
                  state: state,
                  nonce: nonce,
                  code_challenge: code_challenge,
                ),
                allow_other_host: true,
                status: :found,
              )
            end
          end
        end
      end
    end
  end
end
