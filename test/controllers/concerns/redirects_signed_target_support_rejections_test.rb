# typed: false
# frozen_string_literal: true

require "test_helper"

# Signed redirect targets are the only redirect input this application accepts
# from a caller. Both readers refuse rather than guess: a token whose signature
# does not verify resolves to no payload, and a value the URI parser cannot read
# resolves to no path, so neither can become a redirect.
class RedirectsSignedTargetSupportRejectionsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness
    include RedirectsSignedTargetSupport

    def invoke(name, ...) = send(name, ...)
  end

  setup do
    @harness = Harness.new
  end

  test "a token whose signature does not verify resolves to no payload" do
    assert_nil @harness.invoke(
      :verified_signed_target_payload,
      "not-a-signed-token",
      purpose: :path_target,
      salt: "path_target_token",
      expected_flow: "step_up.bootstrap",
      expected_surface: "app",
      session_nonce: "nonce",
    )
  end

  test "a signed target that carries a different flow is refused" do
    token = @harness.invoke(
      :issue_signed_target_token,
      payload: @harness.invoke(
        :signed_target_claims, flow: "other.flow", surface: "app", session_nonce: "nonce",
      ),
      purpose: :path_target,
      salt: "path_target_token",
      expires_in: 5.minutes,
    )

    assert_nil @harness.invoke(
      :verified_signed_target_payload,
      token,
      purpose: :path_target,
      salt: "path_target_token",
      expected_flow: "step_up.bootstrap",
      expected_surface: "app",
      session_nonce: "nonce",
    )
  end

  test "a value the uri parser rejects resolves to no internal path" do
    assert_nil @harness.invoke(:signed_target_internal_path, "https://[")
    assert_equal "/settings", @harness.invoke(:signed_target_internal_path, "/settings")
  end
end
