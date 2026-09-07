# typed: false
# frozen_string_literal: true

require_relative "coverage_threshold_services_test"

class CoverageThresholdStateMachineEdgesTest < ActiveSupport::TestCase
  def ticket(status = "STARTED")
    CoverageThresholdServicesTest::MachineTicket.new(status)
  end
  test "state machine rejects unknown events and malformed payloads" do
    t = ticket

    assert_equal :invalid_transition, SignUpStateMachine.call(ticket: t, event: :unknown, actor_context: nil).status
    machine = SignUpStateMachine.new(ticket: t, event: :start, actor_context: nil, payload: Object.new)

    assert_equal({}, machine.payload)
    t.define_singleton_method(:persisted?) { true }
    t.define_singleton_method(:with_cycle_lock) { |&block| block.call }
    t.define_singleton_method(:reload) { self }

    assert_equal :ok, machine.call.status
  end
  test "state machine checkpoint and finalization guards cover missing payloads" do
    t = ticket("CHECKPOINT_PENDING")
    t.define_singleton_method(:has_attribute?) { |name| name == :checkpoint_version }

    assert_not SignUpStateMachine.new(
      ticket: t, event: :clear_requirement, actor_context: nil,
      payload: { checkpoint_version: "bad" },
    ).send(:checkpoint_version_matches?)
    assert_equal :invalid_transition, SignUpStateMachine.call(ticket: t, event: :finalize, actor_context: nil).status
    t.completed_requirements = { "contact" => { "cleared" => true } }

    assert_equal :invalid_transition,
                 SignUpStateMachine.call(
                   ticket: t, event: :finalize, actor_context: nil,
                   payload: { finalization_result: :rejected },
                 ).status
  end
end
