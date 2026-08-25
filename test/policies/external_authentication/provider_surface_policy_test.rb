# typed: false
# frozen_string_literal: true

require "test_helper"

class ExternalAuthenticationProviderSurfacePolicyTest < ActiveSupport::TestCase
  test "allows the App provider and operation contract" do
    policy = ExternalAuthentication::ProviderSurfacePolicy.new

    %w(apple google).each do |provider|
      %w(login signup link).each do |operation|
        assert policy.allowed?(surface: "app", provider: provider, operation: operation)
      end
    end
  end

  test "allows only Entra login on the Org surface" do
    policy = ExternalAuthentication::ProviderSurfacePolicy.new

    assert policy.allowed?(surface: "org", provider: "entra", operation: "login")
    assert_not policy.allowed?(surface: "org", provider: "entra", operation: "signup")
    assert_not policy.allowed?(surface: "org", provider: "entra", operation: "link")
    assert_not policy.allowed?(surface: "org", provider: "apple", operation: "login")
    assert_not policy.allowed?(surface: "org", provider: "google", operation: "login")
  end

  test "denies Entra on App and every external provider on Com" do
    policy = ExternalAuthentication::ProviderSurfacePolicy.new

    assert_not policy.allowed?(surface: "app", provider: "entra", operation: "login")
    %w(apple google entra).each do |provider|
      assert_not policy.allowed?(surface: "com", provider: provider, operation: "login")
    end
  end

  test "fails closed for unknown contract values" do
    policy = ExternalAuthentication::ProviderSurfacePolicy.new

    assert_not policy.allowed?(surface: "unknown", provider: "apple", operation: "login")
    assert_not policy.allowed?(surface: "app", provider: "unknown", operation: "login")
    assert_not policy.allowed?(surface: "app", provider: "apple", operation: "unlink")
    assert_not policy.allowed?(surface: :app, provider: :apple, operation: :login)
  end
end
