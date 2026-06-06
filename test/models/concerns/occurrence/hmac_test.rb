# typed: false
# frozen_string_literal: true

require "test_helper"

class OccurrenceHmacTest < ActiveSupport::TestCase
  test "secret_credential reads configured credential value" do
    Rails.app.creds.stub(:option, "cred-secret_credential") do
      assert_equal "cred-secret_credential", OccurrenceHmac.secret_credential
    end
  end

  test "email hmac normalizes case and whitespace" do
    Rails.app.creds.stub(:option, "secret_credential") do
      digest_a = OccurrenceHmac.email_hmac(" TEST@Example.com ")
      digest_b = OccurrenceHmac.email_hmac("test@example.com")

      assert_equal digest_a, digest_b
      assert_match(/\A\h{64}\z/, digest_a)
    end
  end

  test "telephone hmac accepts e164 values" do
    Rails.app.creds.stub(:option, "secret_credential") do
      digest = OccurrenceHmac.telephone_hmac("+819012345678")

      assert_match(/\A\h{64}\z/, digest)
    end
  end

  test "telephone hmac rejects blank non international and formatted values" do
    Rails.app.creds.stub(:option, "secret_credential") do
      ["", "09012345678", "+81-90-1234"].each do |telephone|
        assert_raises(OccurrenceHmac::InvalidTelephoneFormatError) do
          OccurrenceHmac.telephone_hmac(telephone)
        end
      end
    end
  end

  test "ip hmac strips surrounding whitespace" do
    Rails.app.creds.stub(:option, "secret_credential") do
      digest_a = OccurrenceHmac.ip_hmac(" 192.0.2.1 ")
      digest_b = OccurrenceHmac.ip_hmac("192.0.2.1")

      assert_equal digest_a, digest_b
    end
  end

  test "secret_credential raises when missing" do
    Rails.app.creds.stub(:option, nil) do
      assert_raises(OccurrenceHmac::MissingSecretError) do
        OccurrenceHmac.secret_credential
      end
    end
  end
end
