# typed: false
# frozen_string_literal: true

require "test_helper"

module Dpop
  class JtiReplayGuardTest < ActiveSupport::TestCase
    setup do
      REDIS_CLIENT.keys("dpop:jti:*").each { |k| REDIS_CLIENT.del(k) }
    end

    teardown do
      REDIS_CLIENT.keys("dpop:jti:*").each { |k| REDIS_CLIENT.del(k) }
    end

    test "record! stores jti and returns true on first record" do
      assert JtiReplayGuard.record!("jti_1")
    end

    test "record! returns false on duplicate jti" do
      JtiReplayGuard.record!("jti_2")

      assert_not JtiReplayGuard.record!("jti_2")
    end

    test "recorded? returns true for known jti" do
      JtiReplayGuard.record!("jti_3")

      assert JtiReplayGuard.recorded?("jti_3")
    end

    test "recorded? returns false for unknown jti" do
      assert_not JtiReplayGuard.recorded?("jti_4")
    end

    test "record! returns false for blank jti" do
      assert_not JtiReplayGuard.record!("")
      assert_not JtiReplayGuard.record!(nil)
    end
  end
end
