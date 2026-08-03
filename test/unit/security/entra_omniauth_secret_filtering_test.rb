# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  # Phase 20 (Entra OmniAuth migration): confirms the parameters a
  # private_key_jwt-based OIDC exchange can produce are filtered from Rails
  # request/parameter logging. See adr/org-entra-id-sign-in-boundary.md and
  # lib/omniauth/strategies/umaxica_entra.rb.
  class EntraOmniauthSecretFilteringTest < ActiveSupport::TestCase
    test "filters OIDC/OmniAuth transport secrets from logged parameters" do
      filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
      filtered = filter.filter(
        "code" => "authorization-code",
        "id_token" => "header.payload.signature",
        "access_token" => "access-token-value",
        "refresh_token" => "refresh-token-value",
        "client_assertion" => "header.payload.signature",
        "client_assertion_type" => "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
        "client_secret" => "should-never-exist-for-entra",
        "code_verifier" => "pkce-verifier",
        "code_challenge" => "pkce-challenge",
        "nonce" => "nonce-value",
        "state" => "state-value",
        "private_key_pem" => "-----BEGIN PRIVATE KEY-----",
        "certificate_pem" => "-----BEGIN CERTIFICATE-----",
      )

      %w(
        code id_token access_token refresh_token client_assertion client_secret
        code_verifier nonce state private_key_pem certificate_pem
      ).each do |key|
        assert_equal "[FILTERED]", filtered.fetch(key), "expected #{key} to be filtered"
      end
    end
  end
end
