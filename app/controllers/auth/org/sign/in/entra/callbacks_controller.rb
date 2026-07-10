# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Sign
      module In
        module Entra
          # Completes the Microsoft Entra ID OIDC sign-in ceremony for operators.
          #
          # GET /sign/in/entra/callback
          # Called by Entra after the operator authenticates. Receives `code`
          # and `state`, exchanges the code, verifies the ID token, and
          # establishes the operator session.
          # Shared ceremony invariants live in OrgEntraCeremony.
          #
          # MFA bypass: `entra_id` is not bypassed (auth_method "entra_id" -> mfa_bypassed? = false).
          # amr claim: "entra_id" written into the access token amr array.
          class CallbacksController < ::Auth::Org::ApplicationController
            include SessionLimitGate
            include OrgEntraCeremony

            AUTHENTICATION_MODE = :guest

            rate_limit(
              to: 10,
              within: 1.minute,
              by: -> { request.remote_ip },
              scope: "auth_org_sign_in_entra",
              name: "callback_ip_burst",
              store: rate_limit_store,
              only: :show,
              with: -> {
                render_rate_limited(rule_name: "auth_org_sign_in_entra_callback_ip_burst", retry_after: 60)
              },
            )

            def show
              expected_state = session.delete(:entra_state)
              return render_entra_error(:state_mismatch) unless secure_equal?(params[:state], expected_state)

              if params[:error].present?
                cleanup_entra_session!
                log_entra_failure("entra_error", error: params[:error])
                return render_entra_error(:entra_error)
              end

              ceremony = consume_entra_session
              return render_entra_error(:connection_not_found) if ceremony[:connection].nil?

              token_result = exchange_code_for_token(ceremony)
              unless token_result.success?
                log_entra_failure("token_exchange_failed", error: token_result.error)
                return render_entra_error(:token_exchange_failed)
              end

              identity, operator = resolve_identity_and_operator(token_result, ceremony, ceremony[:connection])

              unless operator&.login_allowed?
                log_entra_failure("operator_not_allowed", operator_id: identity.operator_id)
                return render_entra_error(:operator_not_found)
              end

              result = establish_signed_in_session!(
                operator,
                pt: ceremony[:pt],
                ri: current_region_identifier,
                auth_method: "entra_id",
              )
              sign_in_result = sign_in_result_from_session_result(result, actor: operator)
              record_authentication_timestamp(identity, sign_in_result)
              handle_sign_in_result(sign_in_result, pt: ceremony[:pt])
            rescue ExternalSignIn::Providers::EntraId::VerificationError => e
              log_entra_failure("token_verification_failed", reason: e.reason)
              render_entra_error(:token_verification_failed)
            rescue ExternalSignIn::IdentityNotFoundError => e
              log_entra_failure("identity_not_found", message: e.message)
              render_entra_error(:identity_not_found)
            rescue StandardError => e
              log_entra_failure("internal_error", error_class: e.class.name, message: e.message, exception: e)
              render_entra_error(:internal_error)
            end

            private

            def consume_entra_session
              {
                connection: find_active_connection_from_session,
                nonce: session.delete(:entra_nonce),
                code_verifier: session.delete(:entra_code_verifier),
                pt: session.delete(:entra_pt),
              }.tap { session.delete(:entra_connection_public_id) }
            end

            def exchange_code_for_token(ceremony)
              OidcRpTokenClient.call(
                token_url: format(OrgEntraCeremony::ENTRA_TOKEN_TEMPLATE, ceremony[:connection].entra_tenant_id),
                client_id: ceremony[:connection].entra_client_id,
                client_secret: ceremony[:connection].entra_client_secret,
                code: params[:code].to_s,
                redirect_uri: auth_org_sign_in_entra_callback_url,
                code_verifier: ceremony[:code_verifier],
              )
            end

            def resolve_identity_and_operator(token_result, ceremony, connection)
              auth_result = ExternalSignIn::Providers::EntraId.new(
                id_token: token_result.token_response["id_token"].to_s,
                expected_nonce: ceremony[:nonce],
                expected_tenant_id: connection.entra_tenant_id,
                client_id: connection.entra_client_id,
              ).call

              resolution = ExternalSignIn::OrgEntraResolver.new(auth_result: auth_result, connection: connection).call
              [resolution.identity, resolution.operator]
            end

            def record_authentication_timestamp(identity, sign_in_result)
              identity.update!(last_authenticated_at: Time.current) if sign_in_result.success?
            end

            def handle_sign_in_result(sign_in_result, pt:)
              if sign_in_result.mfa_required? || sign_in_result.session_limit_pending?
                redirect_to(sign_in_result.redirect_to)
              elsif sign_in_result.terminal?
                render_session_limit_hard_reject(
                  message: sign_in_result.message,
                  http_status: sign_in_result.response_status,
                )
              elsif sign_in_result.success?
                redirect_to_sign_in_sequence!(pt: pt)
              else
                log_entra_failure("sign_in_failed", status: sign_in_result.status)
                render_entra_error(:sign_in_failed)
              end
            end
          end
        end
      end
    end
  end
end
