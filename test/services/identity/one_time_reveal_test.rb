# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentityOneTimeRevealTest < ActiveSupport::TestCase
  fixtures :clients

  setup do
    @cache = ActiveSupport::Cache::MemoryStore.new
  end

  test "reveals value once for matching actor session and purpose" do
    actor = clients(:one)
    Rails.stub(:cache, @cache) do
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
  end

  test "rejects mismatched session" do
    actor = clients(:one)
    Rails.stub(:cache, @cache) do
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
  end

  test "returns nil for malformed/invalid token signature" do
    actor = clients(:one)
    Rails.stub(:cache, @cache) do
      reveal = IdentityOneTimeReveal.consume!(
        actor: actor,
        session_nonce: "session-1",
        token: "completely-malformed-token-or-signature",
        purpose: "test.reveal",
      )

      assert_nil reveal
    end
  end
end
