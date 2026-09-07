# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageThresholdSignedTargetHarness
  include RedirectsSignedTargetSupport

  attr_accessor :request
end

class CoverageThresholdSignedTargetTest < ActiveSupport::TestCase
  setup { @h = CoverageThresholdSignedTargetHarness.new }
  test "signed target claims and path validation cover rejected inputs" do
    assert_nil @h.send(:signed_target_claims, flow: nil, surface: "app", session_nonce: "n")
    assert_nil @h.send(:signed_target_claims, flow: "f", surface: "app", session_nonce: nil)
    assert_equal(
      { "flow" => "f", "surface" => "app", "session_nonce" => "n" },
      @h.send(:signed_target_claims, flow: "f", surface: "app", session_nonce: "n"),
    )
    assert_nil @h.send(:signed_target_internal_path, nil)
    assert_nil @h.send(:signed_target_internal_path, "")
    assert_nil @h.send(:signed_target_internal_path, "https://evil")
    assert_nil @h.send(:signed_target_internal_path, "//evil")
    assert_nil @h.send(:signed_target_internal_path, "/a%2fb")
    assert_nil @h.send(:signed_target_internal_path, "/a\\b")
    assert_equal "/ok?x=1", @h.send(:signed_target_internal_path, "/ok?x=1")
    assert @h.send(
      :signed_target_claims_match?, { "flow" => "f", "surface" => "app" }, expected_flow: "f",
                                                                           expected_surface: "app", session_nonce: nil,
    )
    assert_not @h.send(
      :signed_target_claims_match?, { "flow" => "f", "surface" => "com" }, expected_flow: "f",
                                                                           expected_surface: "app", session_nonce: "n",
    )
    assert_not @h.send(
      :signed_target_claims_match?, { "flow" => "f", "surface" => "app", "session_nonce" => "x" },
      expected_flow: "f", expected_surface: "app", session_nonce: "n",
    )
  end
end
