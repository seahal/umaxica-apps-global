# typed: false
# frozen_string_literal: true

module Base
  module App
    module Oauth
      class AuthorizationsController < Base::App::ApplicationController
        include ::OauthAuthorizeRateLimit

        AUTHENTICATION_MODE = :open
        declare_authentication_mode! :open
        skip_before_action :set_region, raise: false

        def show
          if params[:login_challenge].present?
            transaction =
              OidcAuthorizationTransactionCoordinator.find_by_login_challenge!(
                surface: "app",
                login_challenge: params[:login_challenge].to_s,
              )
            validate_authorization_request!(transaction.authorize_params)
            resume_authorization!(transaction)
          else
            validate_authorization_request!

            if logged_in? && current_client.present?
              issue_authorization_code!(current_client)
            else
              start_authorization_ceremony!
            end
          end
        rescue OidcAuthorizeRequestResolver::InvalidScope => e
          render json: { error: "invalid_scope", error_description: e.message }, status: :bad_request
        # OidcAuthorizeRequestResolver raises ArgumentError with spec-level request
        # descriptions ("scope must include openid", "state is required"), and the registry
        # errors are equally spec-defined. RFC 6749 section 4.1.2.1 expects these in
        # error_description and they disclose nothing about stored data.
        rescue ArgumentError, OidcClientRegistry::ClientNotFound, OidcClientRegistry::InvalidRedirectUri => e
          render json: { error: "invalid_request", error_description: e.message }, status: :bad_request
        # RecordNotFound is different: its message names the model and the primary key that
        # was looked up. The client gets a fixed description; the detail goes to the log.
        rescue ActiveRecord::RecordNotFound => e
          Rails.logger.info(
            JitLogEvent.format(
              "oidc.authorize.invalid_request",
              error_class: e.class.name,
              oidc_client_id: params[:client_id].to_s.presence,
            ),
          )
          render json: { error: "invalid_request", error_description: "invalid authorization request" },
                 status: :bad_request
        end

        private

        def validate_authorization_request!(params_hash = authorize_params)
          @validated_client = OidcAuthorizeRequestResolver.call(
            params: params_hash, resource: current_client, resource_type: resource_type,
          )
        end

        def issue_authorization_code!(resource, params_hash: authorize_params)
          access_claims = Actor.authn.access_claims
          result = ::OidcAuthorizeCoordinator.call(
            params: params_hash,
            resource: resource,
            session_token: current_session,
            auth_method: Array(access_claims&.dig("amr")).first,
            acr: access_claims&.dig("acr"),
          )

          if result.success?
            redirect_to_jump_url(result.redirect_url)
          else
            render json: { error: result.error, error_description: result.error_description },
                   status: :bad_request
          end
        end

        def start_authorization_ceremony!
          issuance =
            OidcAuthorizationTransactionCoordinator.issue!(
              surface: "app",
              intent: authorization_intent,
              params: authorize_params,
            )
          sign_url =
            if authorization_intent == "sign_up"
              auth_app_sign_up_url(
                ri: params[:ri],
                host: oidc_sign_host,
                protocol: oidc_sign_protocol,
                login_challenge: issuance.transaction.login_challenge,
              )
            else
              auth_app_sign_in_url(
                ri: params[:ri],
                host: oidc_sign_host,
                protocol: oidc_sign_protocol,
                login_challenge: issuance.transaction.login_challenge,
              )
            end
          redirect_to_jump_url(sign_url)
        end

        def resume_authorization!(transaction)
          return render(
            json: { error: "invalid_request", error_description: "authorization transaction expired" },
            status: :bad_request,
          ) if transaction.login_challenge_expired?
          return render(
            json: { error: "invalid_request", error_description: "authorization transaction already consumed" },
            status: :bad_request,
          ) if transaction.consumed?
          return render(
            json: { error: "invalid_request", error_description: "authorization transaction is not ready" },
            status: :bad_request,
          ) unless transaction.authenticated?

          resource = Client.find_by!(public_id: transaction.actor_ref)
          login_result =
            ActiveRecord::Base.connected_to(role: :writing) do
              log_in(
                resource,
                record_login_audit: false,
                token_kind_id: "BROWSER_WEB",
                require_totp_check: false,
                audit_context: { oidc_client_id: transaction.client_id },
                bootstrap_actor: true,
              )
            end
          return redirect_to_session_limitation!(
            resource,
            transaction,
          ) if login_result[:status] == :session_limit_hard_reject
          return render(
            json: { error: "invalid_request", error_description: "login_failed" },
            status: :bad_request,
          ) unless login_result[:status] == :success

          transaction.consume!
          issue_authorization_code!(resource, params_hash: transaction.authorize_params)
        end

        def redirect_to_session_limitation!(resource, transaction)
          issuance =
            ClientSessionLimitResolutionTransaction.issue_for_oidc!(
              actor: resource,
              oidc_transaction: transaction,
              audit_context: {
                client_id: transaction.client_id,
                intent: transaction.intent,
              },
            )
          redirect_to(
            base_app_sign_in_limitation_path(resolution_challenge: issuance.challenge),
            status: :see_other,
          )
        end

        def authorization_intent
          (params[:screen_hint].to_s == "signup") ? "sign_up" : "sign_in"
        end

        def oidc_sign_protocol
          URI.parse(OidcIssuer.absolute_url(oidc_sign_host)).scheme
        end

        def authorize_params
          params.permit(
            :response_type, :client_id, :redirect_uri, :state,
            :code_challenge, :code_challenge_method, :scope, :nonce, :screen_hint,
          )
        end
      end
    end
  end
end
