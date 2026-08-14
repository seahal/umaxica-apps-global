# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  # Normalizes a verified Entra ID callback into the same CallbackResult /
  # VerifiedPrincipal shape the Apple and Google adapters produce, so the org
  # surface consumes the app surface's external-authentication interface
  # instead of a parallel one.
  #
  # Claim validation is NOT performed here. The OmniAuth strategy
  # (lib/omniauth/strategies/umaxica_entra.rb) has already run
  # ExternalSignIn::Providers::EntraId, which verifies signature, issuer,
  # audience, nonce, tid, oid, ver and acct. This adapter only maps the
  # already-verified claims the strategy exposes in `extra.raw_info`.
  #
  # Unlike Apple and Google, the subject used downstream is NOT `auth_hash.uid`
  # as an opaque string: Entra identity is the (tid, oid) pair, carried in
  # `tenant_context`. `sub` is retained only as protocol evidence
  # (adr/org-entra-id-sign-in-boundary.md).
  class EntraProviderAdapter
    PROVIDER = "entra"
    VERIFICATION_AUTHORITY =
      "omniauth_openid_connect/#{Gem.loaded_specs.fetch("omniauth_openid_connect").version}".freeze

    def initialize(audience:)
      raise ArgumentError, "audience is required" unless audience.is_a?(String) && audience.present?

      @audience = audience.dup.freeze
    end

    def call(auth_hash:, verified_at:)
      return failed(code: :invalid_callback, safe_reason: :callback_invalid) unless auth_hash.is_a?(OmniAuth::AuthHash)
      return failed(code: :invalid_callback, safe_reason: :provider_mismatch) unless auth_hash.provider == PROVIDER

      raw = auth_hash.extra&.raw_info
      return failed(code: :invalid_callback, safe_reason: :callback_invalid) unless raw.respond_to?(:[])

      subject = raw["sub"].to_s
      issuer = raw["iss"].to_s
      return failed(code: :verification_failed, safe_reason: :assertion_invalid) if subject.blank? || issuer.blank?

      tenant_context = build_tenant_context(raw)
      return failed(code: :verification_failed, safe_reason: :assertion_invalid) if tenant_context.nil?

      CallbackResult.verified(
        principal: VerifiedPrincipal.new(
          provider: PROVIDER,
          subject: subject,
          issuer: issuer,
          audience: @audience,
          verified_at: verified_at,
          verification_authority: VERIFICATION_AUTHORITY,
          tenant_context: tenant_context,
        ),
        credential_candidate: nil,
      )
    end

    private

    # EntraTenantContext raises on a non-UUID tid/oid. The strategy's verifier
    # already rejects those, so reaching the rescue means the AuthHash was not
    # produced by that verified path; classify it as an invalid assertion
    # rather than letting an ArgumentError escape to the callback controller.
    def build_tenant_context(raw)
      EntraTenantContext.new(
        tenant_id: raw["tid"].to_s,
        object_identifier: raw["oid"].to_s,
      )
    rescue ArgumentError
      nil
    end

    def failed(code:, safe_reason:)
      CallbackResult.failed(
        failure: Failure.new(
          code: code,
          provider: PROVIDER,
          retryable: false,
          safe_reason: safe_reason,
        ),
      )
    end
  end
end
