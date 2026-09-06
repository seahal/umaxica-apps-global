# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class IdentityOneTimeRevealTest < ActiveSupport::TestCase
  fixtures :clients

  test "reveals value once for matching actor session and purpose" do
    actor = clients(:one)
    issued = IdentityOneTimeReveal.issue!(
      actor: actor,
      session_nonce: "session-1",
      value: "secret_credential-value",
      purpose: "test.reveal",
      metadata: { source: "test" },
    )

    reveal = IdentityOneTimeReveal.consume!(
      actor: actor,
      session_nonce: "session-1",
      token: issued.token,
      purpose: "test.reveal",
    )

    assert_equal "secret_credential-value", reveal.value
    assert_equal "test", reveal.metadata["source"]

    second_reveal = IdentityOneTimeReveal.consume!(
      actor: actor,
      session_nonce: "session-1",
      token: issued.token,
      purpose: "test.reveal",
    )

    assert_nil second_reveal
  end

  test "rejects mismatched session" do
    actor = clients(:one)
    issued = IdentityOneTimeReveal.issue!(
      actor: actor,
      session_nonce: "session-1",
      value: "secret_credential-value",
      purpose: "test.reveal",
    )

    reveal = IdentityOneTimeReveal.consume!(
      actor: actor,
      session_nonce: "session-2",
      token: issued.token,
      purpose: "test.reveal",
    )

    assert_nil reveal
  end

  test "issue! refuses a missing actor session value or purpose" do
    actor = clients(:one)

    error =
      assert_raises(ArgumentError) do
        IdentityOneTimeReveal.issue!(
          actor: nil, session_nonce: "session-1", value: "secret", purpose: "test.reveal",
        )
      end
    assert_includes error.message, "actor is required"

    error =
      assert_raises(ArgumentError) do
        IdentityOneTimeReveal.issue!(
          actor: actor, session_nonce: "", value: "secret", purpose: "test.reveal",
        )
      end
    assert_includes error.message, "session_nonce is required"

    error =
      assert_raises(ArgumentError) do
        IdentityOneTimeReveal.issue!(
          actor: actor, session_nonce: "session-1", value: "", purpose: "test.reveal",
        )
      end
    assert_includes error.message, "value is required"

    error =
      assert_raises(ArgumentError) do
        IdentityOneTimeReveal.issue!(
          actor: actor, session_nonce: "session-1", value: "secret", purpose: "",
        )
      end
    assert_includes error.message, "purpose is required"
  end

  test "returns nil for malformed/invalid token signature" do
    actor = clients(:one)
    reveal = IdentityOneTimeReveal.consume!(
      actor: actor,
      session_nonce: "session-1",
      token: "completely-malformed-token-or-signature",
      purpose: "test.reveal",
    )

    assert_nil reveal
  end

  test "expired reveal remains unavailable even when its PostgreSQL row exists" do
    actor = clients(:one)
    issued = IdentityOneTimeReveal.issue!(
      actor: actor,
      session_nonce: "session-1",
      value: "secret_credential-value",
      purpose: "test.reveal",
      expires_in: 1.second,
    )

    travel 2.seconds do
      assert_nil IdentityOneTimeReveal.consume!(
        actor: actor,
        session_nonce: "session-1",
        token: issued.token,
        purpose: "test.reveal",
      )
    end
  end
end
