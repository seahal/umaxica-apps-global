# typed: false
# frozen_string_literal: true

require "test_helper"

# Token rotation during a sign-in changes the session public id between the grant
# arriving and the code being submitted, so the ceremony transaction is looked up
# by the stable acme-issued transaction id first and only falls back to the
# session reference. The transaction that lookup accepts must still belong to the
# same actor, the same scope, and still be pending -- otherwise the shortcut
# would let a stale or foreign transaction satisfy a step-up.
class StepUpCeremonyTransactionLookupTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness
    include ::SignVerificationStepUpLifecycle

    attr_accessor :session, :actor_ref, :token_public_id, :step_up_session

    def initialize
      @session = {}
      @actor_ref = "actor-1"
      @token_public_id = "session-1"
    end

    def invoke(name, ...) = send(name, ...)

    def step_up_ceremony_surface = :app

    def step_up_ceremony_actor_ref = actor_ref

    def actor_token = Struct.new(:public_id).new(token_public_id)

    def current_step_up_session = step_up_session

    def current_verification_actor = nil
  end

  def transaction_double(actor_ref: "actor-1", scope: "settings_email", expired: false,
                         status: StepUpCeremonyTransactionable::STATUS_PENDING)
    double = Object.new
    double.define_singleton_method(:actor_ref) { actor_ref }
    double.define_singleton_method(:required_scope) { scope }
    double.define_singleton_method(:expired?) { |**| expired }
    double.define_singleton_method(:status) { status }
    double
  end

  def with_store(find_result: nil, latest: nil, &)
    store = Object.new
    store.define_singleton_method(:find_transaction!) do |_id|
      raise ActiveRecord::RecordNotFound, "no such transaction" if find_result.nil?

      find_result
    end
    store.define_singleton_method(:latest_pending_for) { |**| latest }
    IdentityStepUpCeremonyReplayStore.stub(:for, store, &)
  end

  setup do
    @harness = Harness.new
    @harness.session[:acme_step_up_completion] = { "transaction_id" => "txn-1" }
  end

  test "the stored transaction id is used when it names a pending transaction for this actor and scope" do
    matching = transaction_double

    with_store(find_result: matching) do
      assert_equal matching, @harness.invoke(:current_step_up_ceremony_transaction!, scope: "settings_email")
    end
  end

  test "a stored transaction for another actor, scope, or state falls back to the session lookup" do
    fallback = transaction_double

    [
      transaction_double(actor_ref: "actor-2"),
      transaction_double(scope: "settings_secret"),
      transaction_double(expired: true),
      transaction_double(status: "CONSUMED"),
    ].each do |mismatched|
      with_store(find_result: mismatched, latest: fallback) do
        assert_equal fallback, @harness.invoke(:current_step_up_ceremony_transaction!, scope: "settings_email")
      end
    end
  end

  test "a stored transaction id that names nothing falls back to the session lookup" do
    fallback = transaction_double

    with_store(find_result: nil, latest: fallback) do
      assert_equal fallback, @harness.invoke(:current_step_up_ceremony_transaction!, scope: "settings_email")
    end
  end

  # sign/id must never self-issue a ceremony grant; acme owns step-up intent, so
  # no pending transaction means the request is refused rather than granted.
  test "no pending transaction at all is refused rather than issued locally" do
    with_store(find_result: nil, latest: nil) do
      error =
        assert_raises(ActionController::BadRequest) do
          @harness.invoke(:current_step_up_ceremony_transaction!, scope: "settings_email")
        end

      assert_match(/missing acme step-up ceremony grant/, error.message)
    end
  end

  test "a failed attempt is counted on a session-backed step-up as well as a record-backed one" do
    @harness.step_up_session = { "attempt_count" => 2 }

    @harness.invoke(:record_failed_step_up_attempt!, :email_otp)

    assert_equal 3, @harness.step_up_session["attempt_count"]

    @harness.step_up_session = {}

    @harness.invoke(:record_failed_step_up_attempt!, :email_otp)

    assert_equal 1, @harness.step_up_session["attempt_count"]
  end

  test "the completion hand-off uses Rails' own layout lookup unless a surface names one" do
    assert_nil @harness.invoke(:step_up_handoff_layout)
  end
end
