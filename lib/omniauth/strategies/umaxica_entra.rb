# typed: false
# frozen_string_literal: true

require "omniauth_openid_connect"

module OmniAuth
  module Strategies
    # Umaxica-specific Microsoft Entra ID strategy, subclassing the generic
    # omniauth_openid_connect strategy.
    #
    # What the base strategy already provides and is intentionally NOT
    # reimplemented here: state generation/consumption, nonce generation, and
    # PKCE S256 verifier/challenge handling (session['omniauth.state'],
    # 'omniauth.nonce', 'omniauth.pkce.verifier']).
    #
    # What this subclass adds on top, and why the base strategy cannot cover it:
    # - Request phase, response type, and Discovery: intentional. This app
    #   has no single Entra endpoint; the tenant and client_id are per-
    #   OrganizationEntraConnection, so `options.issuer`/`client_options` are
    #   configured per-request instead of at boot, and Discovery is disabled
    #   (adr/org-entra-id-sign-in-boundary.md).
    # - `access_token`: the base implementation only knows how to send
    #   `client_secret` or a generic (non-certificate) `jwt_bearer` assertion.
    #   Entra requires a certificate-based private_key_jwt with an `x5t#S256`
    #   thumbprint header, produced by the existing
    #   ExternalAuthentication::EntraClientAssertionAdapter.
    # - `verify_id_token!`: the base implementation performs generic OIDC
    #   validation only. This app requires Entra-specific claims (`tid`,
    #   `oid`, `acct`) validated by the existing, already-tested
    #   ExternalSign::Providers::EntraId verifier.
    # - `uid`/`info`/`extra`/`credentials`: the base implementation calls the
    #   UserInfo endpoint and exposes raw tokens. Neither is permitted here
    #   (no Graph/UserInfo calls, no raw token in the AuthHash).
    #
    # OmniAuth::Strategy#call dups the strategy instance per request
    # (lib/omniauth/strategy.rb), so per-request ivars set below
    # (@entra_connection, @verified_entra_result, @access_token) are not
    # shared across concurrent requests.
    class UmaxicaEntra < OpenIDConnect
      option :name, "entra"
      option :response_type, "code"
      option :response_mode, "query"
      option :scope, [:openid, :profile]
      option :send_nonce, true
      option :send_state, true
      option :require_state, true
      option :pkce, true
      option :discovery, false

      CONNECTION_SESSION_KEY = "omniauth.entra.connection_public_id"
      TOKEN_ENDPOINT_TEMPLATE = "https://login.microsoftonline.com/%s/oauth2/v2.0/token"
      AUTHORIZE_ENDPOINT_PATH_TEMPLATE = "/%s/oauth2/v2.0/authorize"
      TOKEN_ENDPOINT_PATH_TEMPLATE = "/%s/oauth2/v2.0/token"
      ISSUER_TEMPLATE = "https://login.microsoftonline.com/%s/v2.0"

      # Raised for domain-level (non-OIDC-transport) failures inside nested
      # calls (access_token, verify_id_token!). `fail!` only produces a
      # correct response when it is the direct return value of a phase
      # method (request_phase/callback_phase); calling it from a method
      # nested inside `super`'s call graph does not halt execution, so
      # those nested paths raise instead and are converted to `fail!` at
      # the top of callback_phase, mirroring the base gem's own
      # CallbackError pattern.
      class Error < StandardError
        attr_reader :reason

        def initialize(reason)
          @reason = reason
          super(reason.to_s)
        end
      end

      # Minimum floor and max sleep intentionally match
      # MinimumResponseBudget (app/controllers/concerns/minimum_response_budget.rb),
      # the equivalent protection the legacy
      # Auth::Org::Sign::In::Entra::AuthorizationsController applied via that
      # controller concern. A Rack/OmniAuth::Strategy is not an
      # ActionController and cannot include that concern, so the same
      # measure-then-pad pattern is inlined here to keep the connection
      # lookup's timing from distinguishing a valid from an invalid
      # connection_public_id.
      MINIMUM_RESPONSE_BUDGET_MS = 150.0
      MAXIMUM_RESPONSE_BUDGET_SLEEP_MS = 250.0

      def request_phase
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        return fail!(:provider_unavailable) unless entra_start_available?

        connection = active_connection_from_params
        if connection.nil?
          pad_to_minimum_response_budget!(started_at)
          return fail!(:connection_not_found)
        end

        session[CONNECTION_SESSION_KEY] = connection.public_id
        configure_for_connection!(connection)
        pad_to_minimum_response_budget!(started_at)
        super
      end

      def callback_phase
        connection = active_connection(session.delete(CONNECTION_SESSION_KEY))
        return fail!(:connection_not_found) if connection.nil?

        @entra_connection = connection
        configure_for_connection!(connection)
        super
      rescue Error => e
        fail!(e.reason)
      end

      # Overrides the base gem's client_secret/generic-jwt_bearer token
      # exchange to inject a certificate-based private_key_jwt assertion
      # (PS256, x5t#S256) built by EntraClientAssertionAdapter, and to run
      # the strict Entra ID token verifier instead of generic OIDC checks.
      def access_token
        return @access_token if defined?(@access_token) && @access_token

        verifier = session.delete("omniauth.pkce.verifier")
        raise Error, :pkce_verifier_missing if verifier.blank?

        assertion =
          begin
            ExternalAuthentication::EntraClientAssertionAdapter.new(
              connection: entra_connection,
              token_url: token_endpoint_url,
            ).call
          rescue ExternalAuthentication::EntraClientAssertionAdapter::ConfigurationError
            raise Error, :client_assertion_unavailable
          end

        @access_token = client.access_token!(
          scope: options.scope,
          client_auth_method: :jwt_bearer,
          client_assertion: assertion,
          code_verifier: verifier,
        )
        verify_id_token!(@access_token.id_token)
        @access_token
      end

      def verify_id_token!(id_token)
        raise Error, :missing_id_token if id_token.blank?

        @verified_entra_result = ExternalSignIn::Providers::EntraId.new(
          id_token: id_token,
          expected_nonce: stored_nonce,
          expected_tenant_id: entra_connection.entra_tenant_id,
          client_id: entra_connection.entra_client_id,
        ).call
      rescue ExternalSignIn::Providers::EntraId::VerificationError => e
        raise Error, e.reason
      end

      def uid
        "#{verified_entra_result.tenant_id}:#{verified_entra_result.entra_object_id}"
      end

      # Plain method overrides, not the `info do ... end` block DSL: the base
      # gem's info/extra/credentials macros MERGE every ancestor's block
      # (OmniAuth::Strategy.compile_stack walks self.class.ancestors), so a
      # block override here would still additionally evaluate the base
      # OpenIDConnect class's blocks -- which call `user_info` (UserInfo
      # endpoint) and expose raw tokens. A plain method definition shadows
      # the base method entirely, the same way `uid` above does.
      def info
        {}
      end

      def extra
        {
          raw_info: {
            "tid" => verified_entra_result.tenant_id,
            "oid" => verified_entra_result.entra_object_id,
            "iss" => verified_entra_result.evidence_issuer,
            "sub" => verified_entra_result.evidence_subject,
            "connection_public_id" => entra_connection.public_id,
          },
        }
      end

      # No raw id_token/access_token/refresh_token in the AuthHash.
      def credentials
        {}
      end

      private

      attr_reader :entra_connection, :verified_entra_result

      def pad_to_minimum_response_budget!(started_at)
        elapsed_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000.0
        remaining_ms = MINIMUM_RESPONSE_BUDGET_MS - elapsed_ms
        return unless remaining_ms.positive?

        sleep([remaining_ms, MAXIMUM_RESPONSE_BUDGET_SLEEP_MS].min / 1000.0)
      end

      # Parity with the legacy Auth::Org::Sign::In::Entra::AuthorizationsController:
      # the request phase must respect the same surface-policy and
      # provider-availability (:social_ceremony_entra Flipper feature) gate, or a
      # provider-disable during an incident would only stop the callback,
      # not new ceremonies.
      def entra_start_available?
        ExternalAuthentication::ProviderSurfacePolicy.new.allowed?(surface: "org", provider: "entra", operation: "login") &&
          ExternalAuthentication::ProviderAvailabilityFactory.current
            .start_decision(provider: "entra", operation: "login", context: {}).state == :enabled
      rescue Redis::BaseError
        false
      end

      def configure_for_connection!(connection)
        tenant_id = connection.entra_tenant_id

        options.issuer = format(ISSUER_TEMPLATE, tenant_id)
        options.client_options.identifier = connection.entra_client_id
        options.client_options.scheme = "https"
        options.client_options.host = "login.microsoftonline.com"
        options.client_options.port = 443
        options.client_options.authorization_endpoint = format(AUTHORIZE_ENDPOINT_PATH_TEMPLATE, tenant_id)
        options.client_options.token_endpoint = format(TOKEN_ENDPOINT_PATH_TEMPLATE, tenant_id)
        options.client_options.redirect_uri = ExternalAuthenticationEntraRedirectUri.call
      end

      def token_endpoint_url
        format(TOKEN_ENDPOINT_TEMPLATE, entra_connection.entra_tenant_id)
      end

      def active_connection_from_params
        active_connection(request.params["connection_public_id"].to_s.strip)
      end

      def active_connection(public_id)
        return if public_id.blank?

        OrganizationEntraConnection.find_by(
          public_id: public_id,
          status_id: OrganizationEntraConnectionState::ACTIVE,
        )
      end
    end
  end
end

OmniAuth.config.add_camelization("umaxica_entra", "UmaxicaEntra")
