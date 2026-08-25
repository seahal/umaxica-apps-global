# typed: false
# frozen_string_literal: true

module ExternalAuthentication
  class ProviderRegistry
    AuthorizationPolicy = Data.define(:scope, :access_type, :prompt)
    Entry =
      Data.define(
        :provider,
        :protocol,
        :issuer,
        :audience_credential_key,
        :request_path,
        :callback_path,
        :callback_origin_key,
        :adapter_key,
        :authorization_policies,
        :issuer_template,
        # Only providers whose issuer is tenant-scoped set this. `issuer` is
        # then nil and the concrete issuer is `issuer_template % tenant_id`,
        # with the tenant read from this credential key.
        :tenant_credential_key,
      )

    APPLE_AUTHORIZATION_POLICIES = %i(login signup link).index_with do
      AuthorizationPolicy.new(scope: "", access_type: nil, prompt: nil)
    end.freeze

    GOOGLE_AUTHORIZATION_POLICIES = %i(login signup link).index_with do
      AuthorizationPolicy.new(
        scope: "openid",
        access_type: "online",
        prompt: "select_account",
      )
    end.freeze

    ENTRA_AUTHORIZATION_POLICIES = {
      login: AuthorizationPolicy.new(scope: "openid profile", access_type: nil, prompt: nil),
    }.freeze

    ENTRIES = {
      "apple" => Entry.new(
        provider: "apple",
        protocol: :oidc,
        issuer: "https://appleid.apple.com",
        audience_credential_key: :OMNI_AUTH_APPLE_CLIENT_ID,
        request_path: "/social/apple",
        callback_path: "/social/apple/callback",
        callback_origin_key: :auth_app,
        adapter_key: :apple_oidc,
        authorization_policies: APPLE_AUTHORIZATION_POLICIES,
        issuer_template: nil,
        tenant_credential_key: nil,
      ),
      "google" => Entry.new(
        provider: "google",
        protocol: :oidc,
        issuer: "https://accounts.google.com",
        audience_credential_key: :OMNI_AUTH_GOOGLE_APP_CLIENT_ID,
        request_path: "/social/google",
        callback_path: "/social/google/callback",
        callback_origin_key: :auth_app,
        adapter_key: :google_oidc,
        authorization_policies: GOOGLE_AUTHORIZATION_POLICIES,
        issuer_template: nil,
        tenant_credential_key: nil,
      ),
      "entra" => Entry.new(
        provider: "entra",
        protocol: :oidc,
        # Tenant-scoped: the concrete issuer is issuer_template % tenant_id.
        issuer: nil,
        audience_credential_key: :OMNI_AUTH_ENTRA_ORG_CLIENT_ID,
        request_path: "/social/entra",
        callback_path: "/social/entra/callback",
        callback_origin_key: :auth_staff,
        adapter_key: :entra_oidc,
        authorization_policies: ENTRA_AUTHORIZATION_POLICIES,
        issuer_template: "https://login.microsoftonline.com/%s/v2.0",
        tenant_credential_key: :OMNI_AUTH_ENTRA_ORG_TENANT_ID,
      ),
    }.freeze

    def self.fetch(provider)
      ENTRIES.fetch(provider)
    rescue KeyError
      raise ArgumentError, "provider is unsupported"
    end

    def self.providers
      ENTRIES.keys
    end

    # Tenant id for a tenant-scoped provider, read from the credential the
    # entry names. Missing configuration raises rather than yielding a
    # provider pointed at an unintended tenant.
    def self.tenant_id(provider)
      entry = fetch(provider)
      key = entry.tenant_credential_key
      raise ArgumentError, "provider is not tenant scoped" if key.nil?

      value = Rails.app.creds.option(key).to_s
      raise KeyError, "credential #{key} is required for the #{provider} provider" if value.blank?

      value
    end

    # Concrete issuer for a provider: the fixed issuer for Apple/Google, or
    # the tenant-substituted issuer for a tenant-scoped provider such as Entra.
    def self.issuer_for(provider)
      entry = fetch(provider)
      return entry.issuer if entry.issuer_template.nil?

      format(entry.issuer_template, tenant_id(provider))
    end

    # Client identifier (OIDC `aud`) for a provider, from the credential the
    # entry names.
    def self.audience(provider)
      entry = fetch(provider)
      key = entry.audience_credential_key
      raise ArgumentError, "provider has no audience credential" if key.nil?

      value = Rails.app.creds.option(key).to_s
      raise KeyError, "credential #{key} is required for the #{provider} provider" if value.blank?

      value
    end
  end
end
