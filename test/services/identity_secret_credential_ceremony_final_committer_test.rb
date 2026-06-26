# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentitySecretCredentialCeremonyFinalCommitterTest < ActiveSupport::TestCase
  setup do
    @now = Time.zone.parse("2026-06-24 12:00:00 UTC")
    @actor = FakeActor.new(id: 7, public_id: "actor-1")
    @transaction = FakeTransaction.new
    @candidate = FakeCandidate.new
  end

  test "commits a secret credential for the app surface and records an audit event" do
    secret_record = Object.new
    audit = nil
    deleted_ref = nil
    credentials_assoc = FakeAssociation.new([], create_result: secret_record)

    with_stubs do
      @actor.stub(:client_secret_credentials, credentials_assoc) do
        ClientSecretCredential.stub(:transaction, ->(&block) { block.call }) do
          IdentitySecretCredentialCeremonyCandidateStore.stub(:delete, ->(ref) { deleted_ref = ref }) do
            IdentityAudit.stub(:record!, ->(**kwargs) { audit = kwargs }) do
              commit = IdentitySecretCredentialCeremonyFinalCommitter.call!(
                result_token: "token",
                actor: @actor,
                session_ref: "session-1",
                surface: "app",
                ip_address: "1.2.3.4",
                user_agent: "UA",
                now: @now,
              )

              assert_same secret_record, commit.secret_credential
            end
          end
        end
      end
    end

    assert_equal "candidate-1", deleted_ref
    assert_equal "API Key", credentials_assoc.created_attrs_sink.first[:name]
    assert_equal "password-digest", credentials_assoc.created_attrs_sink.first[:password_digest]
    assert_equal ClientSecretCredentialStatus::ACTIVE,
                 credentials_assoc.created_attrs_sink.first[:user_identity_secret_status_id]
    assert_equal ClientChronicleEvent::USER_SECRET_CREATED, audit.fetch(:event_id)
    assert_equal ClientSecretCredentialsCreate::ACTION, audit.fetch(:action)
    assert_equal "1.2.3.4", audit.fetch(:ip_address)
  end

  test "raises when the surface is invalid" do
    with_stubs(
      surface: "bad", result_hash: valid_result_hash.merge("surface" => "bad"),
      candidate: FakeCandidate.new(surface: "bad"),
    ) do
      assert_secret_error("surface is invalid") do
        IdentitySecretCredentialCeremonyFinalCommitter.call!(
          result_token: "token", actor: @actor, session_ref: "session-1",
          surface: "bad", now: @now,
        )
      end
    end
  end

  test "raises when the actor is blank" do
    with_stubs do
      assert_secret_error("actor is required") do
        IdentitySecretCredentialCeremonyFinalCommitter.call!(
          result_token: "token", actor: nil, session_ref: "session-1",
          surface: "app", now: @now,
        )
      end
    end
  end

  test "raises when the session ref is blank" do
    with_stubs do
      assert_secret_error("session_ref is required") do
        IdentitySecretCredentialCeremonyFinalCommitter.call!(
          result_token: "token", actor: @actor, session_ref: "",
          surface: "app", now: @now,
        )
      end
    end
  end

  test "raises when the result actor does not match the current actor" do
    with_stubs(result_hash: valid_result_hash.merge("actor_ref" => "other")) do
      assert_secret_error("result actor does not match current actor") do
        IdentitySecretCredentialCeremonyFinalCommitter.call!(
          result_token: "token", actor: @actor, session_ref: "session-1",
          surface: "app", now: @now,
        )
      end
    end
  end

  test "raises when the result session does not match the current session" do
    with_stubs(result_hash: valid_result_hash.merge("session_ref" => "other")) do
      assert_secret_error("result session does not match current session") do
        IdentitySecretCredentialCeremonyFinalCommitter.call!(
          result_token: "token", actor: @actor, session_ref: "session-1",
          surface: "app", now: @now,
        )
      end
    end
  end

  test "raises when the result surface does not match the current surface" do
    with_stubs(result_hash: valid_result_hash.merge("surface" => "com")) do
      assert_secret_error("result surface does not match current surface") do
        IdentitySecretCredentialCeremonyFinalCommitter.call!(
          result_token: "token", actor: @actor, session_ref: "session-1",
          surface: "app", now: @now,
        )
      end
    end
  end

  test "raises when the transaction is expired" do
    with_stubs(transaction: FakeTransaction.new(expired: true)) do
      assert_secret_error("transaction is expired") do
        IdentitySecretCredentialCeremonyFinalCommitter.call!(
          result_token: "token", actor: @actor, session_ref: "session-1",
          surface: "app", now: @now,
        )
      end
    end
  end

  test "raises when the transaction is already consumed" do
    with_stubs(transaction: FakeTransaction.new(consumed: true)) do
      assert_secret_error("transaction is already consumed") do
        IdentitySecretCredentialCeremonyFinalCommitter.call!(
          result_token: "token", actor: @actor, session_ref: "session-1",
          surface: "app", now: @now,
        )
      end
    end
  end

  test "raises when the candidate digest does not match the result" do
    with_stubs(candidate: FakeCandidate.new(digest: "other")) do
      assert_secret_error("candidate digest does not match result") do
        IdentitySecretCredentialCeremonyFinalCommitter.call!(
          result_token: "token", actor: @actor, session_ref: "session-1",
          surface: "app", now: @now,
        )
      end
    end
  end

  test "raises when the candidate actor does not match the current actor" do
    with_stubs(candidate: FakeCandidate.new(actor_ref: "other")) do
      assert_secret_error("candidate actor does not match current actor") do
        IdentitySecretCredentialCeremonyFinalCommitter.call!(
          result_token: "token", actor: @actor, session_ref: "session-1",
          surface: "app", now: @now,
        )
      end
    end
  end

  test "raises when the candidate session does not match the current session" do
    with_stubs(candidate: FakeCandidate.new(session_ref: "other")) do
      assert_secret_error("candidate session does not match current session") do
        IdentitySecretCredentialCeremonyFinalCommitter.call!(
          result_token: "token", actor: @actor, session_ref: "session-1",
          surface: "app", now: @now,
        )
      end
    end
  end

  test "raises when the candidate surface does not match the current surface" do
    with_stubs(candidate: FakeCandidate.new(surface: "com")) do
      assert_secret_error("candidate surface does not match current surface") do
        IdentitySecretCredentialCeremonyFinalCommitter.call!(
          result_token: "token", actor: @actor, session_ref: "session-1",
          surface: "app", now: @now,
        )
      end
    end
  end

  test "raises when the candidate transaction does not match the result" do
    with_stubs(candidate: FakeCandidate.new(transaction_id: "other")) do
      assert_secret_error("candidate transaction does not match result") do
        IdentitySecretCredentialCeremonyFinalCommitter.call!(
          result_token: "token", actor: @actor, session_ref: "session-1",
          surface: "app", now: @now,
        )
      end
    end
  end

  test "raises when the candidate operation does not match the result" do
    with_stubs(candidate: FakeCandidate.new(operation: "deletion")) do
      assert_secret_error("candidate operation does not match result") do
        IdentitySecretCredentialCeremonyFinalCommitter.call!(
          result_token: "token", actor: @actor, session_ref: "session-1",
          surface: "app", now: @now,
        )
      end
    end
  end

  test "raises when the operation is not enrollment" do
    with_stubs(
      result_hash: valid_result_hash.merge("operation" => "deletion"),
      candidate: FakeCandidate.new(operation: "deletion"),
    ) do
      assert_secret_error("operation is invalid") do
        IdentitySecretCredentialCeremonyFinalCommitter.call!(
          result_token: "token", actor: @actor, session_ref: "session-1",
          surface: "app", now: @now,
        )
      end
    end
  end

  test "raises when the secret credential limit is reached" do
    full_assoc = FakeAssociation.new(Array.new(ClientSecretCredential::MAX_SECRETS_PER_USER) { Object.new })

    with_stubs do
      @actor.stub(:client_secret_credentials, full_assoc) do
        IdentitySecretCredentialCeremonyCandidateStore.stub(:delete, ->(_ref) { }) do
          assert_secret_error("secret credential limit is reached") do
            IdentitySecretCredentialCeremonyFinalCommitter.call!(
              result_token: "token", actor: @actor, session_ref: "session-1",
              surface: "app", now: @now,
            )
          end
        end
      end
    end
  end

  test "raises a contract error when the record is invalid" do
    invalid_record = FakeInvalidRecord.new
    failing_assoc = FakeAssociation.new([], create_result: nil, raise_invalid: invalid_record)

    with_stubs do
      @actor.stub(:client_secret_credentials, failing_assoc) do
        ClientSecretCredential.stub(:transaction, ->(&block) { block.call }) do
          IdentitySecretCredentialCeremonyCandidateStore.stub(:delete, ->(_ref) { }) do
            assert_secret_error("secret credential commit failed") do
              IdentitySecretCredentialCeremonyFinalCommitter.call!(
                result_token: "token", actor: @actor, session_ref: "session-1",
                surface: "app", now: @now,
              )
            end
          end
        end
      end
    end
  end

  test "call! class method creates an instance and delegates" do
    assert_secret_error("actor is required") do
      IdentitySecretCredentialCeremonyFinalCommitter.call!(
        result_token: "token", actor: nil, session_ref: "session-1",
        surface: "app", now: @now,
      )
    end
  end

  private

  def with_stubs(surface: "app", result_hash: valid_result_hash, transaction: @transaction,
                 candidate: @candidate)
    store = FakeStore.new(transaction)
    consumer = FakeConsumer.new
    IdentitySecretCredentialCeremonyResult.stub(:decode, ->(_token, **) { result_hash }) do
      IdentitySecretCredentialCeremonyReplayStore.stub(:for, ->(_surface) { store }) do
        IdentitySecretCredentialCeremonyResultConsumer.stub(:new, ->(**) { consumer }) do
          IdentitySecretCredentialCeremonyCandidateStore.stub(:fetch!, ->(_ref) { candidate }) do
            yield
          end
        end
      end
    end
  end

  def assert_secret_error(message)
    error = assert_raises(IdentitySecretCredentialCeremonyContract::Error) { yield }
    assert_includes error.message, message
  end

  def valid_result_hash
    {
      "surface" => "app",
      "actor_ref" => "actor-1",
      "session_ref" => "session-1",
      "transaction_id" => "txn-1",
      "operation" => "enrollment",
      "credential_candidate_ref" => "candidate-1",
      "credential_candidate_digest" => "digest-1",
    }
  end

  class FakeActor
    attr_reader :id, :public_id

    def initialize(id:, public_id:)
      @id = id
      @public_id = public_id
      @secret_credentials = FakeAssociation.new([])
    end

    def blank?
      false
    end

    def present?
      true
    end

    def client_secret_credentials
      @secret_credentials
    end
  end

  class FakeTransaction
    def initialize(expired: false, consumed: false)
      @expired = expired
      @consumed = consumed
    end

    def expired?(*)
      @expired
    end

    def consumed?
      @consumed
    end
  end

  class FakeStore
    def initialize(transaction)
      @transaction = transaction
    end

    def find_transaction!(_id)
      @transaction
    end
  end

  class FakeCandidate
    attr_reader :ref, :digest, :actor_ref, :session_ref, :surface, :transaction_id, :operation,
                :password_digest, :name, :enabled

    def initialize(ref: "candidate-1", digest: "digest-1", actor_ref: "actor-1", session_ref: "session-1",
                   surface: "app", transaction_id: "txn-1", operation: "enrollment",
                   password_digest: "password-digest", name: "API Key", enabled: true)
      @ref = ref
      @digest = digest
      @actor_ref = actor_ref
      @session_ref = session_ref
      @surface = surface
      @transaction_id = transaction_id
      @operation = operation
      @password_digest = password_digest
      @name = name
      @enabled = enabled
    end
  end

  class FakeConsumer
    def call(_token)
      FakeConsumption.new
    end
  end

  class FakeConsumption
    def initialize
      @transaction = Object.new
      @result = {}
    end
    attr_reader :transaction, :result
  end

  class FakeAssociation
    include Enumerable

    attr_reader :created_attrs_sink

    def initialize(records, create_result: Object.new, raise_invalid: nil)
      @records = records
      @create_result = create_result
      @raise_invalid = raise_invalid
      @created_attrs_sink = []
    end

    delegate :count, to: :@records

    def each(&)
      @records.each(&)
    end

    def create!(attrs)
      @created_attrs_sink << attrs
      raise ActiveRecord::RecordInvalid.new(@raise_invalid) if @raise_invalid

      @create_result
    end
  end

  class FakeInvalidRecord
    def self.i18n_scope
      :activerecord
    end

    def errors
      FakeErrors.new
    end
  end

  class FakeErrors
    def full_messages
      ["Name can't be blank"]
    end
  end
end
