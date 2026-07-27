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
          #
          # MFA bypass: `entra_id` is not bypassed (auth_method "entra_id" -> mfa_bypassed? = false).
          # amr claim: "entra_id" written into the access token amr array.
          class CallbacksController < ::Auth::Org::ApplicationController
            include SessionLimitGate
            include ExternalAuthenticationEndpoint

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
              ceremony = ExternalAuthenticationOrgEntraCeremonyStore.new.consume!(
                reference: consume_external_authentication_ceremony_reference,
                callback_state: params[:state].to_s,
                surface: "org",
                provider: "entra",
                operation: "login",
              )
              return render_entra_error(:state_mismatch) if ceremony.nil?
              unless external_authentication_allowed?(surface: "org", provider: "entra", operation: "login") &&
                  external_authentication_callback_available?(provider: "entra", ceremony: ceremony, context: {})
                return render_entra_error(:provider_unavailable)
              end

              if params[:error].present?
                return render_entra_error(:entra_error)
              end

              connection = active_connection(ceremony.connection_public_id)
              return render_entra_error(:connection_not_found) if connection.nil?

              adapter = ExternalAuthentication::ProviderAdapterFactory.build(
                provider: "entra",
                connection: connection,
                redirect_uri: ExternalAuthenticationEntraRedirectUri.call,
              )
              callback_result = adapter.call(
                code: params[:code].to_s,
                expected_nonce: ceremony.nonce,
                code_verifier: ceremony.code_verifier,
              )
              return render_entra_callback_failure(callback_result.failure) if callback_result.failed?

              resolution = adapter.resolve_existing_identity(principal: callback_result.principal)
              identity = resolution.identity
              operator = resolution.operator

              unless operator&.login_allowed?
                log_entra_failure("operator_not_allowed", operator_id: identity.operator_id)
                return render_entra_error(:operator_not_found)
              end

              result = establish_signed_in_session!(
                operator,
                pt: ceremony.return_target,
                ri: current_region_identifier,
                auth_method: "entra_id",
              )
              sign_in_result = sign_in_result_from_session_result(result, actor: operator)
              record_authentication_timestamp(identity, sign_in_result)
              handle_sign_in_result(sign_in_result, pt: ceremony.return_target)
            rescue ExternalSignIn::IdentityNotFoundError
              render_entra_error(:identity_not_found)
            rescue StandardError
              render_entra_error(:internal_error)
            end

            private

            def active_connection(public_id)
              OrganizationEntraConnection.find_by(
                public_id: public_id,
                status_id: OrganizationEntraConnectionState::ACTIVE,
              )
            end

            def render_entra_error(reason)
              @error_reason = reason
              render "auth/org/sign/in/entras/new", status: :unprocessable_content, formats: :html
            end

            def render_entra_callback_failure(failure)
              reason =
                case failure.code
                when :tenant_not_allowed then :tenant_not_allowed
                when :tenant_mismatch then :tenant_mismatch
                when :token_exchange_failed then :token_exchange_failed
                when :invalid_callback then :invalid_callback
                else :token_verification_failed
                end
              render_entra_error(reason)
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
