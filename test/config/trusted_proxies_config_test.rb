# typed: false
# frozen_string_literal: true

require "test_helper"

class TrustedProxiesConfigTest < ActiveSupport::TestCase
  test "required proxy configuration rejects a blank value" do
    error = assert_raises(KeyError) { Jit::TrustedProxiesConfig.parse(nil, required: true) }

    assert_includes error.message, "TRUSTED_PROXIES"
  end

  test "rejects IPv4 and IPv6 catch-all networks" do
    assert_raises(ArgumentError) { Jit::TrustedProxiesConfig.parse("0.0.0.0/0") }
    assert_raises(ArgumentError) { Jit::TrustedProxiesConfig.parse("::/0") }
  end
end
