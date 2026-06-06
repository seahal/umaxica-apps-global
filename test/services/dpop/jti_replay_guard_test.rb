# typed: false
# frozen_string_literal: true

require "test_helper"

module Dpop
  class JtiReplayGuardTest < ActiveSupport::TestCase
    setup do
      ClientDpopProofState.delete_all
    end

    test "record! stores jti and returns true on first record" do
      assert DpopJtiReplayGuard.record!("jti_1")
    end

    test "record! returns false on duplicate jti" do
      DpopJtiReplayGuard.record!("jti_2")

      assert_not DpopJtiReplayGuard.record!("jti_2")
    end

    test "record! returns false for blank jti" do
      assert_not DpopJtiReplayGuard.record!("")
      assert_not DpopJtiReplayGuard.record!(nil)
    end
  end
end
