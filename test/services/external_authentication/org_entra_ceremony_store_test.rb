# typed: false
# frozen_string_literal: true

require "test_helper"

class ExternalAuthenticationOrgEntraCeremonyStoreTest < ActiveSupport::TestCase
  test "keeps two tenant ceremonies isolated when issued before either callback" do
    cache = ActiveSupport::Cache::MemoryStore.new
    store = ExternalAuthenticationOrgEntraCeremonyStore.new(cache: cache)

    reference_a = store.issue!(
      surface: "org",
      provider: "entra",
      operation: "login",
      connection_public_id: "connection-a",
      state: "state-a",
      nonce: "nonce-a",
      code_verifier: "verifier-a",
      return_target: "target-a",
    )
    reference_b = store.issue!(
      surface: "org",
      provider: "entra",
      operation: "login",
      connection_public_id: "connection-b",
      state: "state-b",
      nonce: "nonce-b",
      code_verifier: "verifier-b",
      return_target: "target-b",
    )

    ceremony_b = store.consume!(reference: reference_b, callback_state: "state-b", surface: "org", provider: "entra", operation: "login")
    ceremony_a = store.consume!(reference: reference_a, callback_state: "state-a", surface: "org", provider: "entra", operation: "login")

    assert_equal "connection-b", ceremony_b.connection_public_id
    assert_equal "nonce-b", ceremony_b.nonce
    assert_equal "verifier-b", ceremony_b.code_verifier
    assert_equal "connection-a", ceremony_a.connection_public_id
    assert_equal "nonce-a", ceremony_a.nonce
    assert_equal "verifier-a", ceremony_a.code_verifier
  end

  test "consumes and clears a ceremony when callback state does not match" do
    cache = ActiveSupport::Cache::MemoryStore.new
    store = ExternalAuthenticationOrgEntraCeremonyStore.new(cache: cache)
    reference = store.issue!(
      surface: "org",
      provider: "entra",
      operation: "login",
      connection_public_id: "connection-a",
      state: "state-a",
      nonce: "nonce-a",
      code_verifier: "verifier-a",
      return_target: "target-a",
    )

    result = store.consume!(reference: reference, callback_state: "other-state", surface: "org", provider: "entra", operation: "login")

    assert_nil result
    assert_nil store.consume!(reference: reference, callback_state: "state-a", surface: "org", provider: "entra", operation: "login")
  end

  test "rejects a callback bound to another provider contract" do
    cache = ActiveSupport::Cache::MemoryStore.new
    store = ExternalAuthenticationOrgEntraCeremonyStore.new(cache: cache)
    reference = store.issue!(
      surface: "org",
      provider: "entra",
      operation: "login",
      connection_public_id: "connection-a",
      state: "state-a",
      nonce: "nonce-a",
      code_verifier: "verifier-a",
      return_target: "target-a",
    )

    result = store.consume!(
      reference: reference,
      callback_state: "state-a",
      surface: "app",
      provider: "apple",
      operation: "login",
    )

    assert_nil result
    assert_nil store.consume!(
      reference: reference,
      callback_state: "state-a",
      surface: "org",
      provider: "entra",
      operation: "login",
    )
  end
end
