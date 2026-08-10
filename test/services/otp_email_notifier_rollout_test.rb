# typed: false
# frozen_string_literal: true

require "test_helper"

class OtpEmailNotifierRolloutTest < ActiveSupport::TestCase
  # Stands in for Flipper so each test states its own flag values.
  class StubFlipper
    def initialize(features)
      @features = features
    end

    def enabled?(feature)
      @features.fetch(feature, false)
    end
  end

  test "an unset feature keeps every surface on the legacy mailer path" do
    rollout = OtpEmailNotifierRollout.new(flipper: StubFlipper.new({}))

    OtpEmailNotifierRollout::SURFACE_FEATURE_NAMES.each_key do |surface|
      assert_not rollout.enabled?(surface)
    end
  end

  test "an enabled feature moves only its own surface" do
    rollout = OtpEmailNotifierRollout.new(flipper: StubFlipper.new(otp_email_notifier_app: true))

    assert rollout.enabled?(:app)
    assert_not rollout.enabled?(:com)
    assert_not rollout.enabled?(:org)
  end

  test "a surface given as a string resolves to the same feature" do
    rollout = OtpEmailNotifierRollout.new(flipper: StubFlipper.new(otp_email_notifier_org: true))

    assert rollout.enabled?("org")
  end

  test "an unknown surface is rejected rather than treated as disabled" do
    error =
      assert_raises(ArgumentError) do
        OtpEmailNotifierRollout.new(flipper: StubFlipper.new({})).enabled?(:net)
      end

    assert_match(/unsupported otp email surface/, error.message)
  end

  test "every rollout feature is declared in the feature flag registry" do
    assert_empty OtpEmailNotifierRollout::SURFACE_FEATURE_NAMES.values - FeatureFlags.names
  end
end
