# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignRiskEmitterTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "hmac_email returns nil when email is blank" do
    result = SignRiskEmitter.send(:hmac_email, "")

    assert_nil result
  end

  test "hmac_email returns nil on missing secret error" do
    OccurrenceHmac.stub(:email_hmac, proc { raise OccurrenceHmac::MissingSecretError }) do
      result = SignRiskEmitter.send(:hmac_email, "user@example.com")

      assert_nil result
    end
  end

  test "hmac_ip returns nil when ip is blank" do
    result = SignRiskEmitter.send(:hmac_ip, "")

    assert_nil result
  end

  test "hmac_ip returns nil on missing secret error" do
    OccurrenceHmac.stub(:ip_hmac, proc { raise OccurrenceHmac::MissingSecretError }) do
      result = SignRiskEmitter.send(:hmac_ip, "192.168.1.1")

      assert_nil result
    end
  end

  test "meta_reason extracts reason from meta hash with symbol key" do
    meta = { reason: "suspicious_login" }

    result = SignRiskEmitter.send(:meta_reason, meta)

    assert_equal "suspicious_login", result
  end

  test "meta_reason extracts reason from meta hash with string key" do
    meta = { "reason" => "unusual_location" }

    result = SignRiskEmitter.send(:meta_reason, meta)

    assert_equal "unusual_location", result
  end

  test "meta_reason returns nil when meta has no reason" do
    meta = { other_key: "value" }

    result = SignRiskEmitter.send(:meta_reason, meta)

    assert_nil result
  end

  test "meta_reason returns nil when meta is nil" do
    result = SignRiskEmitter.send(:meta_reason, nil)

    assert_nil result
  end

  test "meta_reason returns nil when meta is empty hash" do
    result = SignRiskEmitter.send(:meta_reason, {})

    assert_nil result
  end
end
