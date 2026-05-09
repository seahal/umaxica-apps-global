# typed: false
# frozen_string_literal: true

require "test_helper"

module Dpop
  class NonceServiceTest < ActiveSupport::TestCase
    setup do
      REDIS_CLIENT.keys("dpop:nonce:*").each { |k| REDIS_CLIENT.del(k) }
    end

    teardown do
      REDIS_CLIENT.keys("dpop:nonce:*").each { |k| REDIS_CLIENT.del(k) }
    end

    test "generate creates a unique nonce" do
      nonce1 = NonceService.generate
      nonce2 = NonceService.generate

      assert_predicate nonce1, :present?
      assert_predicate nonce2, :present?
      assert_not_equal nonce1, nonce2
    end

    test "verify returns true for a generated nonce" do
      nonce = NonceService.generate

      assert NonceService.verify(nonce)
    end

    test "verify returns false for an unknown nonce" do
      assert_not NonceService.verify("unknown_nonce")
    end

    test "verify returns false for blank nonce" do
      assert_not NonceService.verify("")
      assert_not NonceService.verify(nil)
    end

    test "nonce expires after ttl" do
      nonce = NonceService.generate

      assert NonceService.verify(nonce)

      REDIS_CLIENT.del("dpop:nonce:#{nonce}")

      assert_not NonceService.verify(nonce)
    end
  end
end
