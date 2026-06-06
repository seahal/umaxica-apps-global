# typed: false
# frozen_string_literal: true

require "test_helper"

class CommonOtpTest < ActiveSupport::TestCase
  class DummyClass
    include CommonOtp
  end

  setup do
    @obj = DummyClass.new
  end

  test "generate_hotp_code returns valid secret_credential" do
    secret_credential, _counter, _pass_code = @obj.send(:generate_hotp_code)

    assert_not_nil secret_credential
    # Secret should be base32 encoded
    assert_match(/\A[A-Z2-7]+\z/, secret_credential)
  end

  test "generate_hotp_code returns valid counter" do
    _secret_credential, counter, _pass_code = @obj.send(:generate_hotp_code)

    assert_not_nil counter
    # Counter should be even (as per implementation: SecureRandom-seeded value * 2)
    assert_predicate counter, :even?

    # Counter should be within expected range
    assert_includes 2...2_000_000, counter
  end

  test "generate_hotp_code seeds the counter from SecureRandom, not Kernel#rand" do
    # The HOTP counter is a one-time-use secret input and must be derived from a
    # CSPRNG. Stub SecureRandom and assert the counter is the deterministic
    # transform of its output; a regression to Kernel#rand would not match.
    SecureRandom.stub(:random_number, 41) do
      _secret_credential, counter, _pass_code = @obj.send(:generate_hotp_code)

      assert_equal (41 + 1) * 2, counter
    end
  end

  test "generate_hotp_code returns valid pass_code" do
    _secret_credential, _counter, pass_code = @obj.send(:generate_hotp_code)

    assert_not_nil pass_code
    # Pass code should be 6 digits
    assert_match(/\A\d{6}\z/, pass_code)
  end

  test "verify_hotp_code returns true for valid code" do
    secret_credential, counter, pass_code = @obj.send(:generate_hotp_code)

    result = @obj.send(:verify_hotp_code, secret_credential: secret_credential, counter: counter, pass_code: pass_code)

    assert result, "Expected verification to return true for valid pass_code"
  end

  test "verify_hotp_code returns false for invalid code" do
    secret_credential, counter, _pass_code = @obj.send(:generate_hotp_code)
    invalid_code = "000000"

    result = @obj.send(
      :verify_hotp_code, secret_credential: secret_credential, counter: counter,
                         pass_code: invalid_code,
    )

    assert_not result, "Expected verification to return false for invalid pass_code"
  end

  test "verify_hotp_code returns false for wrong counter" do
    secret_credential, counter, pass_code = @obj.send(:generate_hotp_code)
    wrong_counter = counter + 2

    result = @obj.send(
      :verify_hotp_code, secret_credential: secret_credential, counter: wrong_counter,
                         pass_code: pass_code,
    )

    assert_not result, "Expected verification to return false for wrong counter"
  end

  test "verify_hotp_code returns false for wrong secret_credential" do
    _secret_credential, counter, pass_code = @obj.send(:generate_hotp_code)
    wrong_secret_credential = ROTP::Base32.random

    result = @obj.send(
      :verify_hotp_code, secret_credential: wrong_secret_credential, counter: counter,
                         pass_code: pass_code,
    )

    assert_not result, "Expected verification to return false for wrong secret_credential"
  end

  test "generate_hotp_code creates unique codes on each call" do
    codes = 10.times.map { @obj.send(:generate_hotp_code) }

    # Check that we get different secret_credentials
    secret_credentials = codes.map(&:first)

    assert_equal secret_credentials.size, secret_credentials.uniq.size, "Expected all secret_credentials to be unique"

    # Check that we get different counters
    counters = codes.map { |_, c, _| c }

    assert_operator counters.uniq.size, :>, 1, "Expected multiple different counters"
  end

  test "pass_code format is consistent" do
    100.times do
      _secret_credential, _counter, pass_code = @obj.send(:generate_hotp_code)

      assert_equal 6, pass_code.length, "Pass code should be exactly 6 characters"
      assert_match(/\A\d{6}\z/, pass_code, "Pass code should contain only digits")
    end
  end
end
