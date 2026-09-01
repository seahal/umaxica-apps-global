# typed: false
# frozen_string_literal: true

require "test_helper"

# Terminating a sign-up is idempotent: the same terminal event arriving twice has
# to finish the cleanup rather than report a failed transition, because the
# second arrival is usually a retry of a request whose response was lost. An
# event that is not terminal at all is a different thing entirely and is refused.
class SignUpTerminationIdempotenceTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup { ClientSignUpFlowStatus.ensure_defaults! }

  def ticket(status_name)
    ClientSignUpFlow.new(
      step: "contact",
      entry_method: "email",
      status_id: ClientSignUpFlow::STATUS_NAMES.key(status_name),
      issued_at: Time.current,
      expires_at: 1.hour.from_now,
    )
  end

  test "an event that is not a terminal one is refused as an invalid transition" do
    result = SignUpTermination.call(cycle: ticket("STARTED"), event: :advance)

    assert_equal :invalid_transition, result.status
    assert_includes result.errors, "unknown terminal event"
  end

  test "a termination with no ticket is blocked rather than attempted" do
    result = SignUpTermination.call(cycle: nil, event: :cancel)

    assert_equal :blocked, result.status
    assert_includes result.errors, "ticket is required"
  end

  # Each terminal event recognises only its own end state, so a cancelled ticket
  # is not treated as already expired and vice versa.
  test "each terminal event recognises only the end state it produces" do
    expired = SignUpTermination.new(cycle: ticket("EXPIRED"), event: :expire)
    failed = SignUpTermination.new(cycle: ticket("FAILED"), event: :fail)

    assert expired.send(:already_terminal_for_event?)
    assert failed.send(:already_terminal_for_event?)
    assert expired.send(:terminal_status_reached?)
    assert failed.send(:terminal_status_reached?)

    assert_not SignUpTermination.new(cycle: ticket("FAILED"), event: :expire).send(:already_terminal_for_event?)
    assert_not SignUpTermination.new(cycle: ticket("EXPIRED"), event: :fail).send(:already_terminal_for_event?)
    assert_not SignUpTermination.new(cycle: ticket("STARTED"), event: :expire).send(:terminal_status_reached?)
  end

  test "a ticket whose status cannot be read is treated as having reached no end state" do
    unreadable = SignUpTermination.new(cycle: ClientEmail.new, event: :expire)

    assert_nil unreadable.send(:cycle_status_name)
    assert_not unreadable.send(:already_terminal_for_event?)
  end
end
