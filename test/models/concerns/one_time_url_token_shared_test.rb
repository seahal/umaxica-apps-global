# typed: false
# frozen_string_literal: true

require "test_helper"

class OneTimeUrlTokenSharedTest < ActiveSupport::TestCase
  class DummyToken
    include OneTimeUrlTokenShared
  end

  test "generate builds public_id.verifier tokens" do
    token, verifier = DummyToken.generate_one_time_url_token(public_id: "pub")

    assert_match(/\Apub\./, token)
    assert_predicate verifier, :present?
  end

  test "parse splits the token into public_id and verifier" do
    assert_equal ["abc", "def"], DummyToken.parse_one_time_url_token("abc.def")
    assert_nil DummyToken.parse_one_time_url_token("")
    assert_nil DummyToken.parse_one_time_url_token("abc")
  end

  test "digest and secure compare work as expected" do
    expected = DummyToken.digest_one_time_url_verifier("verifier")

    assert_predicate expected, :present?
    assert_equal 48, expected.bytesize
    assert DummyToken.secure_compare?(expected, DummyToken.digest_one_time_url_verifier("verifier"))
    assert_not DummyToken.secure_compare?(expected, DummyToken.digest_one_time_url_verifier("different"))
    assert_not DummyToken.secure_compare?(nil, expected)
  end
end
