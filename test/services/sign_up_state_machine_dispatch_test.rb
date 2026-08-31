# typed: false
# frozen_string_literal: true

require "test_helper"

# The sign-up state machine is the only thing that moves a ticket between states,
# so every arm that answers without transitioning matters: an event it does not
# know, a ticket it cannot lock, and a hand-off result it does not recognise all
# have to answer rather than transition, because a wrong transition leaves a
# ticket in a state no later step accepts.
class SignUpStateMachineDispatchTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup { ClientSignUpFlowStatus.ensure_defaults! }

  def ticket(status_name = "STARTED", step: "start")
    ClientSignUpFlow.new(
      step: step,
      entry_method: "email",
      status_id: ClientSignUpFlow::STATUS_NAMES.key(status_name),
      issued_at: Time.current,
      expires_at: 1.hour.from_now,
    )
  end

  test "an event the machine does not know is refused before any ticket is touched" do
    result = SignUpStateMachine.call(ticket: ticket, event: :teleport, actor_context: nil)

    assert_equal :invalid_transition, result.status
    assert_includes result.errors, "unknown event"
  end

  test "a call with no ticket is refused rather than attempted" do
    result = SignUpStateMachine.call(ticket: nil, event: :start, actor_context: nil)

    assert_equal :invalid_transition, result.status
  end

  # An unpersisted ticket has no row to lock, so the decision is evaluated
  # directly. The lock exists to serialise concurrent writers, not to gate the
  # first transition of a ticket that does not exist yet.
  test "an unpersisted ticket is evaluated without taking a row lock" do
    result = SignUpStateMachine.call(ticket: ticket, event: :start, actor_context: nil)

    assert_equal :ok, result.status
    assert_equal :submit_contact, result.next_event
  end

  # Anything that raises inside the evaluation is answered as an invalid
  # transition carrying the reason, rather than propagating out of the machine.
  test "a transition the ticket refuses is answered as invalid rather than raised" do
    result = SignUpStateMachine.call(ticket: ticket("COMPLETED"), event: :submit_contact, actor_context: nil)

    assert_equal :invalid_transition, result.status
    assert_predicate result.errors, :present?
  end

  test "a terminal state is recognised through the ticket's own predicate and by status otherwise" do
    machine = SignUpStateMachine.new(ticket: ticket("COMPLETED"), event: :complete, actor_context: nil)

    assert machine.send(:terminal?)

    without_predicate = SignUpStateMachine.new(ticket: ticket("STARTED"), event: :complete, actor_context: nil)

    assert_not without_predicate.send(:terminal?)
  end

  test "a payload that is not a hash is normalised to one rather than carried through" do
    machine = SignUpStateMachine.new(ticket: ticket, event: :start, actor_context: nil, payload: nil)

    assert_empty machine.payload
  end
end
