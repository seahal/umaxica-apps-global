# typed: false
# frozen_string_literal: true

require "test_helper"

# Ending a withdrawal early and blocking recovery are both scoped to the
# principal kind: each surface's privacy requests live in its own table, and a
# principal kind this flow does not serve blocks nothing rather than reading
# another surface's rows.
class BaseSettingsWithdrawalFlowTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness(&definition)
    Class.new do
      include BaseSettingsWithdrawalFlow

      attr_reader :redirected, :consumed

      def request = Struct.new(:remote_ip).new("203.0.113.5")

      def consume_current_withdrawal_ceremony!
        @consumed = true
      end

      def safe_redirect_to(target, **)
        @redirected = target
      end

      def withdrawal_public_fallback_path = "/sign/in"

      def withdrawal_new_path = "/identity/withdrawal/new"

      def invoke(name, ...) = send(name, ...)

      class_eval(&definition) if definition
    end.new
  end

  test "an actor that may end its withdrawal early has it terminated before the hand-off" do
    terminated = []
    actor = Struct.new(:early_terminatable?).new(true)
    subject = harness

    WithdrawalLifecycle.stub(:terminate!, ->(**arguments) { terminated << arguments }) do
      subject.invoke(:terminate_withdrawal!, actor)
    end

    assert_equal 1, terminated.size
    assert subject.consumed
    assert_equal "/sign/in", subject.redirected
  end

  test "an actor that may not end its withdrawal early is still handed off" do
    actor = Struct.new(:early_terminatable?).new(false)
    subject = harness
    terminated = []

    WithdrawalLifecycle.stub(:terminate!, ->(**arguments) { terminated << arguments }) do
      subject.invoke(:terminate_withdrawal!, actor)
    end

    assert_empty terminated
    assert subject.consumed
  end

  test "each principal kind is checked for recovery blocks in its own table" do
    subject = harness
    visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)

    assert_not subject.invoke(:privacy_request_blocks_recovery?, visitor)
    assert_not subject.invoke(:privacy_request_blocks_recovery?, client)
    assert_not subject.invoke(:privacy_request_blocks_recovery?, Object.new)
  end
end
