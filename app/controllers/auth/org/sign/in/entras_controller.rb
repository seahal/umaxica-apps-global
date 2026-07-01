# typed: false
# frozen_string_literal: true

require "base64"
require "openssl"

module Auth
  module Org
    module Sign
      module In
        # EntrasController handles Microsoft Entra ID OIDC sign-in for operators.
        #
        # Flow:
        # 1. GET  /sign/in/entra/new           — landing page; operator sees "Sign in with Microsoft"
        # 2. POST /sign/in/entra/authorization  — generate PKCE/state/nonce, redirect to Entra
        # 3. GET  /sign/in/entra/callback       — receive code, exchange, verify, establish session
        #
        # Security invariants:
        # - `state` stored in session provides CSRF protection for the callback.
        # - `nonce` stored in session is verified inside the ID token.
        # - PKCE S256 prevents authorization code interception.
        # - Only pre-provisioned, ACTIVE (OperatorEntraIdentity + connection) operators can sign in.
        # - No JIT provisioning: resolver raises IdentityNotFoundError on any miss.
        # - OmniAuth on the org surface is NOT used; see OmniAuthNonAppSocialGuard.
        #
        # MFA bypass: `entra_id` is not bypassed (auth_method "entra_id" → mfa_bypassed? = false).
        # amr claim: "entra_id" written into the access token amr array.
        # See adr/org-entra-id-sign-in-boundary.md.
        class EntrasController < ::Auth::Org::ApplicationController
          include MinimumResponseBudget
          include SessionLimitGate

          AUTHENTICATION_MODE = :guest

          ENTRA_AUTHORIZE_TEMPLATE = "https://login.microsoftonline.com/%s/oauth2/v2.0/authorize"
          ENTRA_TOKEN_TEMPLATE     = "https://login.microsoftonline.com/%s/oauth2/v2.0/token"
          ENTRA_SCOPE              = "openid profile"
          private_constant :ENTRA_AUTHORIZE_TEMPLATE, :ENTRA_TOKEN_TEMPLATE, :ENTRA_SCOPE

          rate_limit(
            to: 10,
            within: 1.minute,
            by: -> { request.remote_ip },
            scope: "auth_org_sign_in_entra",
            name: "authorization_ip_burst",
            store: rate_limit_store,
            only: :authorization,
            with: -> {
              render_rate_limited(rule_name: "auth_org_sign_in_entra_authorization_ip_burst", retry_after: 60)
            },
          )
          rate_limit(
            to: 10,
            within: 1.minute,
            by: -> { request.remote_ip },
            scope: "auth_org_sign_in_entra",
            name: "callback_ip_burst",
            store: rate_limit_store,
            only: :callback,
            with: -> {
              render_rate_limited(rule_name: "auth_org_sign_in_entra_callback_ip_burst", retry_after: 60)
            },
          )

          before_action :start_minimum_response_budget, only: :authorization
          after_action :enforce_minimum_response_budget, only: :authorization

          # GET /sign/in/entra/new
          # Shows the Entra sign-in landing page with a "Sign in with Microsoft" button.
          # Requires ?connection=PUBLIC_ID to identify which Entra connection to use.
          def new
            connection_public_id = params[:connection].to_s.strip
            @connection = OrganizationEntraConnection.find_by(
              public_id: connection_public_id,
              status_id: OrganizationEntraConnectionState::ACTIVE,
            ) if connection_public_id.present?
          end

          # POST /sign/in/entra/authorization
          # Generates PKCE, stores state/nonce/verifier in session, redirects to Entra.
          def authorization
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

          # GET /sign/in/entra/callback
          # Called by Entra after the operator authenticates. Receives `code` and `state`.
          def callback
            # Read and immediately clear the state to prevent replay.
            expected_state = session.delete(:entra_state)
            return render_entra_error(:state_mismatch) unless secure_equal?(params[:state], expected_state)

            # Entra returned an error (e.g., user denied consent, account not in tenant).
            # Clear remaining session keys before returning to avoid stale state accumulation.
            if params[:error].present?
              cleanup_entra_session!
              log_entra_failure("entra_error", error: params[:error])
              return render_entra_error(:entra_error)
            end

            connection    = find_active_connection_from_session
            nonce         = session.delete(:entra_nonce)
            code_verifier = session.delete(:entra_code_verifier)
            pt            = session.delete(:entra_pt)
            session.delete(:entra_connection_public_id)

            return render_entra_error(:connection_not_found) if connection.nil?

            token_result = OidcRpTokenClient.call(
              token_url: format(ENTRA_TOKEN_TEMPLATE, connection.entra_tenant_id),
              client_id: connection.entra_client_id,
              client_secret: connection.entra_client_secret,
              code: params[:code].to_s,
              redirect_uri: callback_auth_org_sign_in_entra_url,
              code_verifier: code_verifier,
            )

            unless token_result.success?
              log_entra_failure("token_exchange_failed", error: token_result.error)
              return render_entra_error(:token_exchange_failed)
            end

            auth_result = ExternalSignIn::Providers::EntraId.new(
              id_token: token_result.token_response["id_token"].to_s,
              expected_nonce: nonce,
              expected_tenant_id: connection.entra_tenant_id,
              client_id: connection.entra_client_id,
            ).call

            identity = ExternalSignIn::OrgEntraResolver.new(auth_result: auth_result).call

            operator = Operator.find_by(id: identity.operator_id)
            unless operator&.login_allowed?
              log_entra_failure("operator_not_allowed", operator_id: identity.operator_id)
              return render_entra_error(:operator_not_found)
            end

            result = establish_signed_in_session!(
              operator,
              pt: pt,
              ri: current_region_identifier,
              auth_method: "entra_id",
            )
            sign_in_result = sign_in_result_from_session_result(result, actor: operator)
            # Record the successful authentication only after the session is established.
            identity.update_column(:last_authenticated_at, Time.current) if sign_in_result.success?
            handle_sign_in_result(sign_in_result, pt: pt)
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

          def cleanup_entra_session!
            session.delete(:entra_nonce)
            session.delete(:entra_code_verifier)
            session.delete(:entra_pt)
            session.delete(:entra_connection_public_id)
          end

          def find_active_connection_from_params
            public_id = entra_params[:connection_public_id].to_s.strip
            return if public_id.blank?

            OrganizationEntraConnection.find_by(
              public_id: public_id,
              status_id: OrganizationEntraConnectionState::ACTIVE,
            )
          end

          def find_active_connection_from_session
            public_id = session[:entra_connection_public_id].to_s
            return if public_id.blank?

            OrganizationEntraConnection.find_by(
              public_id: public_id,
              status_id: OrganizationEntraConnectionState::ACTIVE,
            )
          end

          def entra_params
            params.fetch(:entra, {}).permit(:connection_public_id)
          end

          def build_entra_authorization_url(connection:, state:, nonce:, code_challenge:)
            base = format(ENTRA_AUTHORIZE_TEMPLATE, connection.entra_tenant_id)
            query = {
              client_id: connection.entra_client_id,
              response_type: "code",
              redirect_uri: callback_auth_org_sign_in_entra_url,
              scope: ENTRA_SCOPE,
              state: state,
              nonce: nonce,
              code_challenge: code_challenge,
              code_challenge_method: "S256",
            }.to_query
            "#{base}?#{query}"
          end

          def pkce_s256_challenge(code_verifier)
            digest = OpenSSL::Digest::SHA256.digest(code_verifier)
            Base64.urlsafe_encode64(digest, padding: false)
          end

          def handle_sign_in_result(sign_in_result, pt:)
            if sign_in_result.mfa_required?
              redirect_to(sign_in_result.redirect_to)
            elsif sign_in_result.terminal?
              render_session_limit_hard_reject(
                message: sign_in_result.message,
                http_status: sign_in_result.response_status,
              )
            elsif sign_in_result.session_limit_pending?
              redirect_to(sign_in_result.redirect_to)
            elsif sign_in_result.success?
              redirect_to_sign_in_sequence!(pt: pt)
            else
              log_entra_failure("sign_in_failed", status: sign_in_result.status)
              render_entra_error(:sign_in_failed)
            end
          end

          def render_entra_error(reason)
            @error_reason = reason
            render :new, status: :unprocessable_content, formats: :html
          end

          def log_entra_failure(event, **context)
            Rails.logger.info(
              JitLogEvent.format(
                "sign.org.authentication.entra.failed",
                event: event,
                ip: request.remote_ip,
                ri: current_region_identifier,
                **context,
              ),
            )
          end

          def secure_equal?(a, b)
            a = a.to_s
            b = b.to_s
            return false if a.empty? || b.empty?
            return false if a.bytesize != b.bytesize

            ActiveSupport::SecurityUtils.secure_compare(a, b)
          end
        end
      end
    end
  end
end
