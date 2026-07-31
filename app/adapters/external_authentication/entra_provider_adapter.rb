# typed: false
# frozen_string_literal: true

require "base64"
require "openssl"

module ExternalAuthentication
  class EntraProviderAdapter
    AUTHORIZE_ENDPOINT = "https://login.microsoftonline.com/%s/oauth2/v2.0/authorize"
    TOKEN_ENDPOINT = "https://login.microsoftonline.com/%s/oauth2/v2.0/token"
    SCOPE = "openid profile"

    def initialize(
      connection:,
      redirect_uri:,
      token_client: OidcRpTokenClient,
      verifier_class: ExternalSignIn::Providers::EntraId,
      jwks_loader: nil,
      clock: -> { Time.current },
      client_assertion_provider: nil
    )
      @connection = connection
      @redirect_uri = redirect_uri
      @token_client = token_client
      @verifier_class = verifier_class
      @jwks_loader = jwks_loader
      @clock = clock
      @client_assertion_provider = client_assertion_provider || lambda do |connection:, token_url:, clock:|
        EntraClientAssertionAdapter.new(connection: connection, token_url: token_url, clock: clock).call
      end
    end

    def authorization_url(state:, nonce:, code_challenge:)
      validate_start_inputs!(state: state, nonce: nonce, code_challenge: code_challenge)
      query = {
        client_id: connection.entra_client_id,
        response_type: "code",
        redirect_uri: redirect_uri,
        scope: SCOPE,
        state: state,
        nonce: nonce,
        code_challenge: code_challenge,
        code_challenge_method: "S256",
      }.to_query

      "#{format(AUTHORIZE_ENDPOINT, connection.entra_tenant_id)}?#{query}"
    end

    def call(code:, expected_nonce:, code_verifier:)
      token_url = format(TOKEN_ENDPOINT, connection.entra_tenant_id)
      client_assertion = @client_assertion_provider.call(
        connection: connection,
        token_url: token_url,
        clock: @clock,
      )
      token_result = token_client.call(
        token_url: token_url,
        client_id: connection.entra_client_id,
        client_secret: nil,
        client_assertion: client_assertion,
        code: code,
        redirect_uri: redirect_uri,
        code_verifier: code_verifier,
      )
      return failed(:token_exchange_failed, :token_exchange_failed, true) unless token_result.success?

      normalized = verifier_class.new(
        id_token: token_result.token_response.fetch("id_token", "").to_s,
        expected_nonce: expected_nonce,
        expected_tenant_id: connection.entra_tenant_id,
        client_id: connection.entra_client_id,
        jwks_loader: @jwks_loader,
        clock: @clock,
      ).call

      CallbackResult.verified(
        principal: VerifiedPrincipal.new(
          provider: "entra",
          subject: normalized.evidence_subject,
          issuer: normalized.evidence_issuer,
          audience: connection.entra_client_id,
          verified_at: @clock.call,
          verification_authority: "external_sign_in_entra_id",
          tenant_context: EntraTenantContext.new(
            tenant_id: normalized.tenant_id,
            object_identifier: normalized.entra_object_id,
          ),
        ),
      )
    rescue ExternalSignIn::Providers::EntraId::VerificationError => e
      verification_failure(e.reason)
    rescue EntraClientAssertionAdapter::ConfigurationError
      raise
    rescue KeyError, ArgumentError, TypeError, OpenSSL::PKey::PKeyError, OpenSSL::X509::CertificateError
      failed(:invalid_callback, :callback_invalid, false)
    end

    def resolve_existing_identity(principal:)
      unless principal.is_a?(VerifiedPrincipal) && principal.provider == "entra"
        raise ArgumentError, "Entra principal is required"
      end

      auth_result = ExternalSignIn::NormalizedAuthResult.new(
        tenant_id: principal.tenant_context.tenant_id,
        entra_object_id: principal.tenant_context.object_identifier,
        evidence_issuer: principal.issuer,
        evidence_subject: principal.subject,
      )
      ExternalSignIn::OrgEntraResolver.new(auth_result: auth_result, connection: connection).call
    end

    def self.pkce_s256_challenge(code_verifier)
      digest = OpenSSL::Digest::SHA256.digest(code_verifier)
      Base64.urlsafe_encode64(digest, padding: false)
    end

    private

    attr_reader :connection, :redirect_uri, :token_client, :verifier_class

    def validate_start_inputs!(state:, nonce:, code_challenge:)
      raise ArgumentError, "state is required" if state.blank?
      raise ArgumentError, "nonce is required" if nonce.blank?
      raise ArgumentError, "code_challenge is required" if code_challenge.blank?
      raise ArgumentError, "redirect_uri is required" if redirect_uri.blank?
    end

    def verification_failure(reason)
      case reason
      when "personal_account_tenant", "guest_account_not_allowed", "account_type_missing"
        failed(:tenant_not_allowed, :tenant_not_allowed, false)
      when "tid_mismatch"
        failed(:tenant_mismatch, :tenant_mismatch, false)
      else
        failed(:verification_failed, :assertion_invalid, false)
      end
    end

    def failed(code, safe_reason, retryable)
      CallbackResult.failed(
        failure: Failure.new(
          code: code,
          provider: "entra",
          retryable: retryable,
          safe_reason: safe_reason,
        ),
      )
    end
  end
end
