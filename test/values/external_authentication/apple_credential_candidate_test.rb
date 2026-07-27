# typed: false
# frozen_string_literal: true

require "test_helper"

class ExternalAuthenticationAppleCredentialCandidateTest < ActiveSupport::TestCase
  test "holds only the callback refresh token for the credential repository" do
    candidate = ExternalAuthentication::AppleCredentialCandidate.new(
      refresh_token: "callback-refresh-token",
    )

    assert_equal "callback-refresh-token", candidate.refresh_token
    assert_predicate candidate, :frozen?
    assert_not_includes candidate.inspect, "callback-refresh-token"
    assert_not_includes candidate.to_s, "callback-refresh-token"
  end

  test "rejects a missing refresh token" do
    error =
      assert_raises(ArgumentError) do
        ExternalAuthentication::AppleCredentialCandidate.new(refresh_token: "")
      end

    assert_equal "refresh_token is required", error.message
  end

  test "refuses generic JSON serialization" do
    candidate = ExternalAuthentication::AppleCredentialCandidate.new(
      refresh_token: "callback-refresh-token",
    )

    error = assert_raises(TypeError) { candidate.as_json }

    assert_equal "Apple credential candidates cannot be serialized", error.message
  end
end
