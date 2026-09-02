# typed: false
# frozen_string_literal: true

require "test_helper"

# Binding and candidate checks on the social-ceremony committer. These are the
# fail-closed branches that a successful link/login/signup never walks.
class IdentitySocialCeremonyFinalCommitterGuardsTest < ActiveSupport::TestCase
  test "refuses a blank session_ref" do
    error =
      assert_raises(IdentitySocialCeremonyContract::Error) do
        committer(session_ref: "").send(:validate_binding!)
      end
    assert_includes error.message, "session_ref is required"
  end

  test "link operation refuses a blank actor and an actor mismatch" do
    actor = Struct.new(:public_id).new("actor-1")
    error =
      assert_raises(IdentitySocialCeremonyContract::Error) do
        committer(actor: nil, result: { "operation" => "link" }).send(:validate_binding!)
      end
    assert_includes error.message, "actor is required"

    error =
      assert_raises(IdentitySocialCeremonyContract::Error) do
        committer(actor: actor, result: { "operation" => "link", "actor_ref" => "other" }).send(:validate_binding!)
      end
    assert_includes error.message, "result actor does not match current actor"
  end

  test "non-link operation refuses an actor that does not match the transaction" do
    error =
      assert_raises(IdentitySocialCeremonyContract::Error) do
        committer(
          result: { "operation" => "login",
                    "actor_ref" => "other",
                    "session_ref" => "session-1",
                    "surface" => "app", },
          transaction: Struct.new(:actor_ref).new("txn-actor"),
        ).send(:validate_binding!)
      end
    assert_includes error.message, "result actor does not match transaction"
  end

  test "refuses session and surface mismatches" do
    txn = Struct.new(:actor_ref).new("actor-1")
    error =
      assert_raises(IdentitySocialCeremonyContract::Error) do
        committer(
          result: { "operation" => "login", "actor_ref" => "actor-1", "session_ref" => "other", "surface" => "app" },
          transaction: txn,
        ).send(:validate_binding!)
      end
    assert_includes error.message, "result session does not match current session"

    error =
      assert_raises(IdentitySocialCeremonyContract::Error) do
        committer(
          result: { "operation" => "login",
                    "actor_ref" => "actor-1",
                    "session_ref" => "session-1",
                    "surface" => "com", },
          transaction: txn,
        ).send(:validate_binding!)
      end
    assert_includes error.message, "result surface does not match current surface"
  end

  test "refuses expired and already consumed transactions" do
    expired = Object.new
    expired.define_singleton_method(:expired?) { |**| true }
    expired.define_singleton_method(:consumed?) { false }
    error =
      assert_raises(IdentitySocialCeremonyContract::Error) do
        committer(transaction: expired).send(:validate_transaction_state!)
      end
    assert_includes error.message, "transaction is expired"

    consumed = Object.new
    consumed.define_singleton_method(:expired?) { |**| false }
    consumed.define_singleton_method(:consumed?) { true }
    error =
      assert_raises(IdentitySocialCeremonyContract::Error) do
        committer(transaction: consumed).send(:validate_transaction_state!)
      end
    assert_includes error.message, "transaction is already consumed"
  end

  test "validate_candidate! refuses a blank candidate and every binding mismatch" do
    instance = committer(
      result: {
        "candidate_digest" => "digest",
        "actor_ref" => "actor-1",
        "operation" => "login",
        "provider" => "google",
      },
      transaction: Struct.new(:transaction_id).new("txn-1"),
    )

    error =
      assert_raises(IdentitySocialCeremonyContract::Error) do
        instance.send(:validate_candidate!, nil)
      end
    assert_includes error.message, "result candidate is required"

    candidate = Struct.new(
      :digest, :surface, :actor_ref, :session_ref, :transaction_id, :operation, :provider,
    ).new("other", "app", "actor-1", "session-1", "txn-1", "login", "google")
    error =
      assert_raises(IdentitySocialCeremonyContract::Error) do
        instance.send(:validate_candidate!, candidate)
      end
    assert_includes error.message, "result candidate digest does not match"
  end

  test "signup refuses a blank or ineligible birthdate" do
    instance = committer(result: { "birthdate" => "", "candidate_ref" => "cand" })
    instance.define_singleton_method(:validate_candidate!) { |_candidate| true }
    error =
      assert_raises(IdentitySocialCeremonyContract::Error) do
        IdentitySocialCeremonyCandidateStore.stub(:consume!, Object.new) do
          instance.send(:commit_signup!, Object.new)
        end
      end
    assert_includes error.message, "birthdate is required"

    instance = committer(result: { "birthdate" => Time.zone.today.to_s, "candidate_ref" => "cand" })
    instance.define_singleton_method(:validate_candidate!) { |_candidate| true }
    error =
      assert_raises(IdentitySocialCeremonyContract::Error) do
        IdentitySocialCeremonyCandidateStore.stub(:consume!, Object.new) do
          instance.send(:commit_signup!, Object.new)
        end
      end
    assert_includes error.message, "birthdate is ineligible"
  end

  test "record_audit! is a no-op when identity is blank" do
    assert_nil committer.send(:record_audit!, nil)
  end

  test "transaction return fields are nil when the transaction does not expose them" do
    instance = committer(transaction: Object.new)

    assert_nil instance.send(:transaction_return_to)
    assert_nil instance.send(:transaction_return_entry)
  end

  private

  def committer(actor: nil, session_ref: "session-1", result: { "operation" => "login" }, transaction: nil)
    instance = IdentitySocialCeremonyFinalCommitter.new(
      result_token: "token",
      actor: actor,
      session_ref: session_ref,
      surface: "app",
    )
    instance.define_singleton_method(:result) { result }
    instance.define_singleton_method(:transaction) { transaction } if transaction
    instance.define_singleton_method(:operation) { result["operation"].to_s }
    instance
  end
end
