# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class WebauthnConfigTest < ActiveSupport::TestCase
  # Case A-1: trusted origins not set
  # Tested via method behavior

  test "validate_origin! raises error when origin is not trusted" do
    # WebAuthn trusted origins are enforced to be set in test environment via Rails configuration
    # We test the validation logic against the configured values

    assert_raises(WebAuthn::OriginVerificationError) do
      Webauthn.validate_origin!("http://malicious.example.com")
    end
  end

  # Case A-2: Validate trusted origins

  test "validate_origin! returns true for trusted origins" do
    # Assuming config is loaded properly in test env
    trusted_origin = Webauthn.trusted_origins.first

    assert Webauthn.validate_origin!(trusted_origin)
  end

  test "trusted_origins returns origins loaded from env" do
    assert_not_empty Webauthn.trusted_origins
  end

  test "parse_trusted_origins derives origins from public auth hosts without TRUSTED_ORIGINS" do
    with_webauthn_origin_env(
      "PUBLIC_AUTH_SERVICE_URL" => "auth.umaxica.app",
      "PUBLIC_AUTH_CORPORATE_URL" => "auth.umaxica.com",
      "PUBLIC_AUTH_STAFF_URL" => "auth.umaxica.org",
    ) do
      origins = Webauthn.send(:parse_trusted_origins)

      assert_includes origins, "http://auth.umaxica.app"
      assert_includes origins, "https://auth.umaxica.app"
      assert_includes origins, "http://auth.umaxica.com"
      assert_includes origins, "https://auth.umaxica.com"
      assert_includes origins, "http://auth.umaxica.org"
      assert_includes origins, "https://auth.umaxica.org"
    end
  end

  test "parse_trusted_origins keeps TRUSTED_ORIGINS as optional additional origins" do
    with_webauthn_origin_env(
      "PUBLIC_AUTH_SERVICE_URL" => "auth.umaxica.app",
      "PUBLIC_AUTH_CORPORATE_URL" => "auth.umaxica.com",
      "PUBLIC_AUTH_STAFF_URL" => "auth.umaxica.org",
      "TRUSTED_ORIGINS" => "https://passkey.example.test",
    ) do
      origins = Webauthn.send(:parse_trusted_origins)

      assert_includes origins, "https://auth.umaxica.app"
      assert_includes origins, "https://passkey.example.test"
    end
  end

  test "parse_trusted_origins still raises when no origin source is configured" do
    with_webauthn_origin_env do
      assert_raises(Webauthn::TrustedOriginsNotConfiguredError) do
        Webauthn.send(:parse_trusted_origins)
      end
    end
  end

  # Regression guard for FINDING-08: production must not fall back to request.host for rpId.
  test "validate_rp_id_configuration! raises MissingRpIdError in production when no RP_ID vars are set" do
    rp_id_keys = %w(WEBAUTHN_APP_RP_ID WEBAUTHN_COM_RP_ID WEBAUTHN_ORG_RP_ID WEBAUTHN_RP_ID)
    saved = rp_id_keys.index_with { |k| ENV.delete(k) }

    Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
      assert_raises(Webauthn::MissingRpIdError) { Webauthn.validate_rp_id_configuration! }
    end
  ensure
    saved.each { |k, v| ENV[k] = v if v }
  end

  test "validate_rp_id_configuration! does not raise in production when shared WEBAUTHN_RP_ID is set" do
    saved = ENV.delete("WEBAUTHN_RP_ID")
    ENV["WEBAUTHN_RP_ID"] = "id.app.example.com"

    Rails.stub(:env, ActiveSupport::StringInquirer.new("production")) do
      assert_nothing_raised { Webauthn.validate_rp_id_configuration! }
    end
  ensure
    saved ? ENV["WEBAUTHN_RP_ID"] = saved : ENV.delete("WEBAUTHN_RP_ID")
  end

  test "validate_rp_id_configuration! is a no-op outside production regardless of env vars" do
    rp_id_keys = %w(WEBAUTHN_APP_RP_ID WEBAUTHN_COM_RP_ID WEBAUTHN_ORG_RP_ID WEBAUTHN_RP_ID)
    saved = rp_id_keys.index_with { |k| ENV.delete(k) }

    assert_nothing_raised { Webauthn.validate_rp_id_configuration! }
  ensure
    saved.each { |k, v| ENV[k] = v if v }
  end

  private

  def with_webauthn_origin_env(overrides = {})
    keys = %w(
      PUBLIC_AUTH_SERVICE_URL
      PUBLIC_AUTH_CORPORATE_URL
      PUBLIC_AUTH_STAFF_URL
      WEBAUTHN_APP_ORIGIN
      WEBAUTHN_COM_ORIGIN
      WEBAUTHN_ORG_ORIGIN
      WEBAUTHN_ORIGIN
      TRUSTED_ORIGINS
    )
    saved = keys.index_with { |key| ENV[key] }

    keys.each { |key| ENV.delete(key) }
    overrides.each { |key, value| ENV[key] = value }

    yield
  ensure
    saved.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
