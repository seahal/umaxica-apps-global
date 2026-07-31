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
      ),
      "entra" => Entry.new(
        provider: "entra",
        protocol: :oidc,
        issuer: nil,
        audience_credential_key: nil,
        request_path: "/sign/in/entra/authorization",
        callback_path: "/sign/in/entra/callback",
        callback_origin_key: :auth_staff,
        adapter_key: :entra_oidc,
        authorization_policies: ENTRA_AUTHORIZATION_POLICIES,
        issuer_template: "https://login.microsoftonline.com/%s/v2.0",
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
  end
end
