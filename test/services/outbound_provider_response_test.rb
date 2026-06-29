# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OutboundProviderResponseTest < ActiveSupport::TestCase
  test "accepted stores provider details" do
    time = Time.current
    result = OutboundProviderResponse.accepted(
      provider: :aws_sns,
      provider_reference: "ref-123",
      accepted_at: time,
    )

    assert_equal "aws_sns", result.provider
    assert_equal "ref-123", result.provider_reference
    assert_equal time, result.accepted_at
  end

  test "accepted coerces values to strings" do
    result = OutboundProviderResponse.accepted(
      provider: :aws_sns,
      provider_reference: 123,
    )

    assert_equal "aws_sns", result.provider
    assert_equal "123", result.provider_reference
  end

  test "accepted defaults accepted_at to now" do
    before = Time.current
    result = OutboundProviderResponse.accepted(provider: :test, provider_reference: "x")
    after = Time.current

    assert_operator before, :<=, result.accepted_at
    assert_operator result.accepted_at, :<=, after
  end
end
