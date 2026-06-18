# typed: false
# frozen_string_literal: true

require "test_helper"
require Rails.root.join("lib/config_values_origin_value").to_s

class ConfigValuesOriginValueTest < ActiveSupport::TestCase
  test "rejects query userinfo and bad scheme" do
    assert_raises(ArgumentError) { ConfigValues.build("ftp://example.com") }
    assert_raises(ArgumentError) { ConfigValues.build("https://user@example.com") }
    assert_raises(ArgumentError) { ConfigValues.build("https://example.com?x=1") }
  end

  test "allows localhost http only in local mode" do
    assert_nothing_raised { ConfigValues.build("http://localhost:3000", allow_localhost: true) }
    assert_raises(ArgumentError) { ConfigValues.build("http://example.com", allow_localhost: true) }
  end
end
