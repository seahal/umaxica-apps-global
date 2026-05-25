# typed: false
# frozen_string_literal: true

require "test_helper"

class ReturnTargetTokenTest < ActiveSupport::TestCase
  ISSUE = {
    return_to: "/configuration/passkeys",
    flow: "verification.bootstrap",
    surface: "app",
    session_nonce: "abc123",
  }.freeze

  test "round-trip returns the verified destination, flow, and surface" do
    token = ReturnTargetToken.issue(**ISSUE)
    payload = ReturnTargetToken.verify!(
      token,
      expected_flow: ISSUE[:flow],
      expected_surface: ISSUE[:surface],
      session_nonce: ISSUE[:session_nonce],
    )

    assert_equal "/configuration/passkeys", payload["return_to"]
    assert_equal ISSUE[:flow], payload["flow"]
    assert_equal ISSUE[:surface], payload["surface"]
  end

  test "verified_return_to returns the path on success" do
    token = ReturnTargetToken.issue(**ISSUE)
    path = ReturnTargetToken.verified_return_to(
      token,
      expected_flow: ISSUE[:flow],
      expected_surface: ISSUE[:surface],
      session_nonce: ISSUE[:session_nonce],
    )

    assert_equal "/configuration/passkeys", path
  end

  test "verified_return_to returns nil for invalid tokens" do
    assert_nil ReturnTargetToken.verified_return_to(
      "garbage",
      expected_flow: "any",
      expected_surface: "app",
      session_nonce: "abc123",
    )
  end

  test "rejects blank tokens" do
    error =
      assert_raises(ReturnTargetToken::Invalid) do
        ReturnTargetToken.verify!(
          "",
          expected_flow: ISSUE[:flow], expected_surface: ISSUE[:surface],
          session_nonce: ISSUE[:session_nonce],
        )
      end
    assert_equal "blank_token", error.message
  end

  test "rejects flow mismatch" do
    token = ReturnTargetToken.issue(**ISSUE)
    error =
      assert_raises(ReturnTargetToken::Invalid) do
        ReturnTargetToken.verify!(
          token,
          expected_flow: "different.flow", expected_surface: ISSUE[:surface],
          session_nonce: ISSUE[:session_nonce],
        )
      end
    assert_equal "wrong_flow", error.message
  end

  test "rejects surface mismatch" do
    token = ReturnTargetToken.issue(**ISSUE)
    error =
      assert_raises(ReturnTargetToken::Invalid) do
        ReturnTargetToken.verify!(
          token,
          expected_flow: ISSUE[:flow], expected_surface: "com",
          session_nonce: ISSUE[:session_nonce],
        )
      end
    assert_equal "wrong_surface", error.message
  end

  test "rejects session nonce mismatch when an expectation is given" do
    token = ReturnTargetToken.issue(**ISSUE)
    error =
      assert_raises(ReturnTargetToken::Invalid) do
        ReturnTargetToken.verify!(
          token,
          expected_flow: ISSUE[:flow], expected_surface: ISSUE[:surface],
          session_nonce: "different-nonce",
        )
      end
    assert_equal "wrong_session", error.message
  end

  test "rejects tampered tokens" do
    token = ReturnTargetToken.issue(**ISSUE)
    tampered = token.sub(/.\z/, "Z")
    error =
      assert_raises(ReturnTargetToken::Invalid) do
        ReturnTargetToken.verify!(
          tampered,
          expected_flow: ISSUE[:flow], expected_surface: ISSUE[:surface],
          session_nonce: ISSUE[:session_nonce],
        )
      end
    assert_equal "invalid_signature", error.message
  end

  test "rejects expired tokens" do
    token = ReturnTargetToken.issue(**ISSUE, expires_in: 1.second)
    travel 5.seconds do
      error =
        assert_raises(ReturnTargetToken::Invalid) do
          ReturnTargetToken.verify!(
            token,
            expected_flow: ISSUE[:flow], expected_surface: ISSUE[:surface],
            session_nonce: ISSUE[:session_nonce],
          )
        end
      assert_equal "invalid_signature", error.message
    end
  end

  test "rejects absolute URLs at issue time" do
    error =
      assert_raises(ReturnTargetToken::Invalid) do
        ReturnTargetToken.issue(
          return_to: "https://attacker.example.com/path",
          flow: ISSUE[:flow], surface: ISSUE[:surface], session_nonce: ISSUE[:session_nonce],
        )
      end
    assert_equal "blank_return_to", error.message
  end

  test "rejects protocol-relative URLs at issue time" do
    error =
      assert_raises(ReturnTargetToken::Invalid) do
        ReturnTargetToken.issue(
          return_to: "//attacker.example.com/path",
          flow: ISSUE[:flow], surface: ISSUE[:surface], session_nonce: ISSUE[:session_nonce],
        )
      end
    assert_equal "blank_return_to", error.message
  end

  test "rejects userinfo URLs at issue time" do
    error =
      assert_raises(ReturnTargetToken::Invalid) do
        ReturnTargetToken.issue(
          return_to: "//user:pass@host/path",
          flow: ISSUE[:flow], surface: ISSUE[:surface], session_nonce: ISSUE[:session_nonce],
        )
      end
    assert_equal "blank_return_to", error.message
  end

  test "rejects control characters in path at issue time" do
    error =
      assert_raises(ReturnTargetToken::Invalid) do
        ReturnTargetToken.issue(
          return_to: "/configuration/passkeys\nLocation: https://attacker",
          flow: ISSUE[:flow], surface: ISSUE[:surface], session_nonce: ISSUE[:session_nonce],
        )
      end
    assert_equal "blank_return_to", error.message
  end

  test "rejects blank flow, surface, or session nonce at issue time" do
    assert_raises(ReturnTargetToken::Invalid) do
      ReturnTargetToken.issue(return_to: "/a", flow: "", surface: "app", session_nonce: "n")
    end
    assert_raises(ReturnTargetToken::Invalid) do
      ReturnTargetToken.issue(return_to: "/a", flow: "f", surface: "", session_nonce: "n")
    end
    assert_raises(ReturnTargetToken::Invalid) do
      ReturnTargetToken.issue(return_to: "/a", flow: "f", surface: "app", session_nonce: "")
    end
  end

  test "verify requires a non-empty expected flow and surface" do
    token = ReturnTargetToken.issue(**ISSUE)
    error =
      assert_raises(ReturnTargetToken::Invalid) do
        ReturnTargetToken.verify!(
          token, expected_flow: "", expected_surface: ISSUE[:surface],
                 session_nonce: ISSUE[:session_nonce],
        )
      end
    assert_equal "blank_expected_flow", error.message

    error =
      assert_raises(ReturnTargetToken::Invalid) do
        ReturnTargetToken.verify!(
          token, expected_flow: ISSUE[:flow], expected_surface: "",
                 session_nonce: ISSUE[:session_nonce],
        )
      end
    assert_equal "blank_expected_surface", error.message
  end

  test "verify with a blank caller-side session nonce accepts any nonce in payload" do
    token = ReturnTargetToken.issue(**ISSUE)
    payload = ReturnTargetToken.verify!(
      token,
      expected_flow: ISSUE[:flow], expected_surface: ISSUE[:surface],
      session_nonce: "",
    )

    assert_equal "/configuration/passkeys", payload["return_to"]
  end
end
