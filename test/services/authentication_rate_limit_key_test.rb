# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthenticationRateLimitKeyTest < ActiveSupport::TestCase
  test "normalizes identifiers without exposing them in the key" do
    first = AuthenticationRateLimitKey.for(surface: :app, identifier: " User@Example.COM ")
    second = AuthenticationRateLimitKey.for(surface: :app, identifier: "user@example.com")

    assert_equal first, second
    assert_not_includes first, "user@example.com"
  end

  test "separates equal identifiers across surfaces" do
    app = AuthenticationRateLimitKey.for(surface: :app, identifier: "same@example.com")
    com = AuthenticationRateLimitKey.for(surface: :com, identifier: "same@example.com")

    assert_not_equal app, com
  end

  test "uses an explicit unbound key for blank identifiers" do
    assert_equal "app:unbound", AuthenticationRateLimitKey.for(surface: :app, identifier: " ")
  end
end
