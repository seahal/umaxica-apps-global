# typed: false
# frozen_string_literal: true

require "test_helper"

class WebauthnConfigTest < ActiveSupport::TestCase
  # Case A-1: TRUSTED_ORIGINS not set
  # Tested via method behavior

  test "validate_origin! raises error when origin is not trusted" do
    # TRUSTED_ORIGINS is enforced to be set in test environment via Rails configuration
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

  test "trusted_origins returns invalid origins loaded from env" do
    assert_not_empty Webauthn.trusted_origins
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
end
