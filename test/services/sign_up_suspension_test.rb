# typed: false
# frozen_string_literal: true

require "test_helper"

class SignUpSuspensionTest < ActiveSupport::TestCase
  # Stands in for Flipper so each test states its own flag values.
  class StubFlipper
    def initialize(features)
      @features = features
    end

    def enabled?(feature)
      @features.fetch(feature, false)
    end
  end

  test "an unset feature leaves registration open on every surface" do
    suspension = SignUpSuspension.new(flipper: StubFlipper.new({}))

    SignUpSuspension::SURFACE_FEATURE_NAMES.each_key do |surface|
      assert_not suspension.suspended?(surface)
    end
  end

  test "an enabled feature closes only its own surface" do
    suspension = SignUpSuspension.new(flipper: StubFlipper.new(sign_up_suspended_app: true))

    assert suspension.suspended?(:app)
    assert_not suspension.suspended?(:com)
    assert_not suspension.suspended?(:org)
  end

  test "a surface given as a string resolves to the same feature" do
    suspension = SignUpSuspension.new(flipper: StubFlipper.new(sign_up_suspended_org: true))

    assert suspension.suspended?("org")
  end

  test "an unknown surface is rejected rather than treated as open" do
    error =
      assert_raises(ArgumentError) do
        SignUpSuspension.new(flipper: StubFlipper.new({})).suspended?(:net)
      end

    assert_match(/unsupported sign up surface/, error.message)
  end
end
