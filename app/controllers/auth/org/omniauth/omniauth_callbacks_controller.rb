# typed: false
# frozen_string_literal: true

module Auth
  module Org
    module Omniauth
      # OmniAuth callback boundary for the org (staff) surface.
      #
      # Routes:
      #   GET /social/entra/callback -> #omniauth
      #   GET /social/entra/failure  -> #failure
      #
      # The strategy (lib/omniauth/strategies/umaxica_entra.rb) already
      # performed PKCE/state/nonce validation and Entra ID token verification
      # before this controller runs; `request.env["omniauth.auth"]` carries
      # only verified, minimal claims (tid, oid, iss, sub -- never raw tokens,
      # never email/UPN/name).
      #
      # This controller is Rails glue only: it normalizes the AuthHash through
      # the same ExternalAuthentication adapter interface the app surface uses
      # for Google and Apple, delegates identity lookup to
      # ExternalSignIn::OrgEntraResolver (no JIT provisioning), and routes
      # through the same session-establishment, MFA, session-limit, and audit
      # path as the passkey and secret-credential ceremonies.
      # See adr/org-entra-id-sign-in-boundary.md.
      class OmniauthCallbacksController < ::Auth::Org::ApplicationController
        include SessionLimitGate
        include ExternalAuthenticationEndpoint

        AUTHENTICATION_MODE = :guest

        # The callback GET is a cross-site redirect from Microsoft; region/
        # localization canonicalization before_actions would otherwise
        # redirect it before the callback is processed (mirrors
        # Auth::App::Omniauth::OmniauthCallbacksController).
        skip_before_action :apply_localization_preferences, only: %i(omniauth failure), raise: false
        skip_before_action :set_region, only: %i(omniauth failure), raise: false

        rate_limit(
          to: 10,
          within: 1.minute,
          by: -> { request.remote_ip },
          scope: "auth_org_sign_in_entra",
          name: "omniauth_callback_ip_burst",
          store: rate_limit_store,
          only: :omniauth,
          with: -> {
            render_rate_limited(retry_after: 60)
          },
        )

        def omniauth
          auth = request.env["omniauth.auth"]
          return render_entra_error(:invalid_callback) unless auth.is_a?(OmniAuth::AuthHash) && auth.provider == "entra"

          unless external_authentication_allowed?(surface: "org", provider: "entra", operation: "login") &&
              external_authentication_callback_available?(provider: "entra", ceremony: {}, context: {})
            return render_entra_error(:provider_unavailable)
          end

          callback = ExternalAuthentication::ProviderAdapterFactory.build(
            provider: "entra",
            audience: ExternalAuthentication::ProviderRegistry.audience("entra"),
          ).call(auth_hash: auth, verified_at: Time.current)
          return render_entra_error(:invalid_callback) if callback.failed?

          resolution = ExternalSignIn::OrgEntraResolver.new(
            tenant_context: callback.principal.tenant_context,
          ).call
          identity = resolution.identity
          operator = resolution.operator

          unless operator&.login_allowed?
            log_entra_failure("operator_not_allowed", operator_id: identity.operator_id)
            return render_entra_error(:operator_not_found)
          end

          return if reject_locked_authentication_method!(identity: identity, operator: operator)

          # The callback is a GET (Entra redirects back with `code`/`state`);
          # establish_signed_in_session! and its session-limit/status-enum
          # bootstrap writes must not run against a read replica.
          sign_in_result, pt =
            ActiveRecord::Base.connected_to(role: :writing) do
            result = establish_signed_in_session!(
              operator,
              pt: consume_pt!,
              ri: current_region_identifier,
              auth_method: "entra_id",
            )
            resolved_sign_in_result = sign_in_result_from_session_result(result, actor: operator)
            record_authentication_timestamp(identity, resolved_sign_in_result)
            [resolved_sign_in_result, consume_pt!]
          end
          handle_sign_in_result(sign_in_result, pt: pt)
        rescue ExternalSignIn::IdentityNotFoundError
          render_entra_error(:identity_not_found)
        rescue StandardError => e
          log_entra_failure("internal_error", error_class: e.class.name)
          render_entra_error(:internal_error)
        end

        # GET /social/entra/failure
        # `message` is an unauthenticated, unthrottled request parameter (the
        # rate_limit above is scoped to :omniauth), so it is classified through
        # the same allowlist used for rendering before it reaches the log. Only
        # the classification is retained; the raw parameter is never logged
        # (adr/application-logging-boundary.md).
        def failure
          reason = entra_failure_reason(params[:message].presence || "unknown_error")
          log_entra_failure("omniauth_failure", message: reason)
          render_entra_error(reason)
        end

        private

        def entra_failure_reason(message)
          case message
          when "connection_not_found", "pkce_verifier_missing", "client_assertion_unavailable",
               "missing_id_token", "tenant_not_allowed", "tenant_mismatch"
            message.to_sym
          else
            :entra_error
          end
        end

        def consume_pt!
          @consumed_pt = session.delete(::Auth::Org::Social::SessionsController::PT_SESSION_KEY) unless defined?(@consumed_pt)
          @consumed_pt
        end

        # Provider exception messages can contain response bodies or claim
        # payloads; retain only allowlisted classification metadata
        # (adr/application-logging-boundary.md).
        def log_entra_failure(reason, **payload)
          Rails.logger.warn(
            JitLogEvent.format(
              "sign.org.authentication.entra.callback_failure",
              reason: reason,
              **payload,
            ),
          )
        end

        def render_entra_error(reason)
          @error_reason = reason
          render :error, status: :unprocessable_content, formats: :html
        end

        def reject_locked_authentication_method!(identity:, operator:)
          locked = external_authentication_method_locked?(
            enforcement_case_class: OrgEnforcementCase,
            principal_public_id: operator.public_id,
            authentication_method: "entra",
          )
          return false unless locked

          log_entra_failure("authentication_method_locked", operator_id: identity.operator_id)
          render_entra_error(:authentication_method_locked)
          true
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
