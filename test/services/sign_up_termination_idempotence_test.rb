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

  test "a cancelled ticket is recognised only by the cancel event" do
    cancelled = ticket("CANCELLED")
    cancelled.define_singleton_method(:sign_up_cancelled?) { true }

    assert SignUpTermination.new(cycle: cancelled, event: :cancel).send(:already_terminal_for_event?)
    assert SignUpTermination.new(cycle: cancelled, event: :cancel).send(:terminal_status_reached?)
    assert_not SignUpTermination.new(cycle: ticket("STARTED"), event: :cancel).send(:already_terminal_for_event?)
  end

  test "replaying a terminal event without cleanup support is a no-op success" do
    expired = Object.new
    expired.define_singleton_method(:status_id) { ClientSignUpFlow::STATUS_NAMES.key("EXPIRED") }
    klass =
      Class.new do
        const_set(:STATUS_NAMES, ClientSignUpFlow::STATUS_NAMES)
      end
    expired.define_singleton_method(:class) { klass }
    expired.define_singleton_method(:reload) { expired }
    expired.define_singleton_method(:step) { "contact" }
    expired.define_singleton_method(:respond_to?) { |name, *| %i(cleanup_pending? discard_now!).exclude?(name) }

    result = SignUpTermination.call(cycle: expired, event: :expire)

    assert_equal :ok, result.status
    assert_equal expired, result.ticket
  end

  test "schedule_terminal_retention! records pending cleanup when the cycle supports it" do
    cycle = TicketWithCleanup.new
    SignUpTermination.new(cycle: cycle, event: :fail).send(:schedule_terminal_retention!)

    assert_equal :pending, cycle.cleanup_status_id
    assert_nil cycle.cleanup_error_code
    assert_nil cycle.cleanup_attempted_at
    assert_nil cycle.cleanup_completed_at
    assert cycle.discarded
  end

  test "ensure_cleanup_pending! is a no-op when cleanup is already pending or completed" do
    pending = TicketWithCleanup.new(cleanup_status_id: :pending)
    completed = TicketWithCleanup.new(cleanup_status_id: :completed)
    SignUpTermination.new(cycle: pending, event: :fail).send(:ensure_cleanup_pending!)
    SignUpTermination.new(cycle: completed, event: :fail).send(:ensure_cleanup_pending!)

    assert_equal :pending, pending.cleanup_status_id
    assert_equal :completed, completed.cleanup_status_id
  end

  test "run_artifact_cleanup skips completed cycles and calls cleanup otherwise" do
    completed = TicketWithCleanup.new(cleanup_status_id: :completed)
    pending = TicketWithCleanup.new(cleanup_status_id: :pending)
    called = nil
    SignUpTermination.new(cycle: completed, event: :fail).send(:run_artifact_cleanup)
    SignUpArtifactCleanup.stub(:call, ->(**kwargs) { called = kwargs }) do
      SignUpTermination.new(cycle: pending, event: :fail).send(:run_artifact_cleanup)
    end

    assert_nil completed.cleanup_error_code
    assert_equal({ cycle: pending }, called)
  end

  class TicketWithCleanup
    attr_accessor :cleanup_status_id, :cleanup_error_code, :cleanup_attempted_at, :cleanup_completed_at, :discarded

    def initialize(cleanup_status_id: nil)
      @cleanup_status_id = cleanup_status_id
      @discarded = false
    end

    def respond_to?(name, include_all = false)
      return true if %i(discard_now! cleanup_pending? cleanup_completed? cleanup_status_id_for).include?(name)

      super
    end

    def has_attribute?(name)
      %w(cleanup_status_id cleanup_error_code cleanup_attempted_at cleanup_completed_at).include?(name.to_s)
    end

    def cleanup_pending? = cleanup_status_id == :pending

    def cleanup_completed? = cleanup_status_id == :completed

    def cleanup_status_id_for(name) = name

    def discard_now!(purge_after:)
      @discarded = true
      purge_after
    end

    def with_cycle_lock
      yield
    end

    def reload = self

    def update!(attrs)
      attrs.each { |key, value| public_send("#{key}=", value) }
    end
  end
end
