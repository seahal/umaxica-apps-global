# typed: false
# frozen_string_literal: true

require "test_helper"

class OccurrenceHmacTest < ActiveSupport::TestCase
  def with_env_secret(value)
    previous = ENV["OCCURRENCE_HMAC_SECRET"]
    ENV["OCCURRENCE_HMAC_SECRET"] = value
    yield
  ensure
    if previous.nil?
      ENV.delete("OCCURRENCE_HMAC_SECRET")
    else
      ENV["OCCURRENCE_HMAC_SECRET"] = previous
    end
  end

  test "creds option returns secret" do
    fake_creds = Object.new
    fake_creds.define_singleton_method(:option) { |_key, **| "cred-secret" }

    Rails.app.stub(:creds, fake_creds) do
      assert_equal "cred-secret", Occurrence::Hmac.secret
    end
  end

  test "email normalization produces consistent digest" do
    with_env_secret("secret") do
      digest_a = Occurrence::Hmac.email_hmac(" TEST@Example.com ")
      digest_b = Occurrence::Hmac.email_hmac("test@example.com")

      assert_equal digest_a, digest_b
    end
  end

  test "telephone must start with plus and only digits" do
    with_env_secret("secret") do
      assert_raises(Occurrence::Hmac::InvalidTelephoneFormatError) do
        Occurrence::Hmac.telephone_hmac("")
      end

      assert_raises(Occurrence::Hmac::InvalidTelephoneFormatError) do
        Occurrence::Hmac.telephone_hmac("09012345678")
      end

      assert_raises(Occurrence::Hmac::InvalidTelephoneFormatError) do
        Occurrence::Hmac.telephone_hmac("+81-90-1234")
      end

      digest = Occurrence::Hmac.telephone_hmac("+819012345678")

      assert_match(/\A\h{64}\z/, digest)
    end
  end

  test "ip hmac strips surrounding whitespace" do
    with_env_secret("secret") do
      digest_a = Occurrence::Hmac.ip_hmac(" 192.0.2.1 ")
      digest_b = Occurrence::Hmac.ip_hmac("192.0.2.1")

      assert_equal digest_a, digest_b
    end
  end

  test "secret raises when missing" do
    fake_creds = Object.new
    fake_creds.define_singleton_method(:option) { |_key, **| nil }

    Rails.app.stub(:creds, fake_creds) do
      assert_raises(Occurrence::Hmac::MissingSecretError) do
        Occurrence::Hmac.secret
      end
    end
  end
end
