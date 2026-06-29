# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Dpop
  class NonceServiceTest < ActiveSupport::TestCase
    setup do
      ClientDpopProofState.delete_all
    end

    test "generate creates a unique nonce" do
      nonce1 = DpopNonceService.generate
      nonce2 = DpopNonceService.generate

      assert_predicate nonce1, :present?
      assert_predicate nonce2, :present?
      assert_not_equal nonce1, nonce2
    end

    test "verify returns true for a generated nonce" do
      nonce = DpopNonceService.generate

      assert DpopNonceService.verify(nonce)
    end

    test "verify returns false for an unknown nonce" do
      assert_not DpopNonceService.verify("unknown_nonce")
    end

    test "verify returns false for blank nonce" do
      assert_not DpopNonceService.verify("")
      assert_not DpopNonceService.verify(nil)
    end

    test "nonce is single use" do
      nonce = DpopNonceService.generate

      assert DpopNonceService.verify(nonce)
      assert_not DpopNonceService.verify(nonce)
    end
  end
end
