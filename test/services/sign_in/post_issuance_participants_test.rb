# typed: false
# frozen_string_literal: true

require "test_helper"

module SignIn
  class PostIssuanceParticipantsTest < ActiveSupport::TestCase
    test "empty checkpoint stack advances to dashboard" do
      actor = create_client
      cycle = create_cycle(actor, status_name: "CHECKPOINT_PENDING")

      result = CheckpointParticipant.new(cycle: cycle, actor: actor).advance_if_clear!

      assert_predicate result, :empty?
      assert_predicate result, :cleared?
      assert_predicate cycle.reload, :sign_in_dashboard_pending?
      assert_equal "dashboard", cycle.step
    end

    test "blocking checkpoint item keeps cycle at checkpoint" do
      actor = create_client
      cycle = create_cycle(actor, status_name: "CHECKPOINT_PENDING")
      evaluator =
        lambda do |**|
          ParticipantItem.new(key: :bulletin, blocking: true, cleared: false)
        end

      result = CheckpointParticipant.new(cycle: cycle, actor: actor, evaluators: [evaluator]).advance_if_clear!

      assert_predicate result, :blocking?
      assert_equal [:bulletin], result.stack.map(&:key)
      assert_predicate cycle.reload, :sign_in_checkpoint_pending?
      assert_equal "checkpoint", cycle.step
    end

    test "dashboard always advances to return pending after evaluation" do
      actor = create_client
      cycle = create_cycle(actor, status_name: "DASHBOARD_PENDING")
      evaluator =
        lambda do |**|
          ParticipantItem.new(key: :welcome, blocking: false, cleared: false)
        end

      result = DashboardParticipant.new(cycle: cycle, actor: actor, evaluators: [evaluator]).advance!

      assert_not_predicate result, :blocking?
      assert_equal [:welcome], result.stack.map(&:key)
      assert_predicate cycle.reload, :sign_in_return_pending?
      assert_equal "return_to", cycle.step
    end

    test "return participant consumes safe return path and completes cycle" do
      actor = create_client
      cycle = create_cycle(actor, status_name: "RETURN_PENDING", return_to: "/settings?tab=sessions")

      destination = ReturnParticipant.new(cycle: cycle, default_path: "/configuration").consume!

      assert_equal "/settings?tab=sessions", destination
      assert_predicate cycle.reload, :sign_in_completed?
      assert_equal "completed", cycle.step
      assert_not_nil cycle.completed_at
      assert_nil cycle.return_to
    end

    test "return participant discards unsafe return path and completes cycle with default" do
      actor = create_client
      cycle = create_cycle(actor, status_name: "RETURN_PENDING", return_to: "https://evil.example/path")

      destination = ReturnParticipant.new(cycle: cycle, default_path: "/configuration").consume!

      assert_equal "/configuration", destination
      assert_predicate cycle.reload, :sign_in_completed?
      assert_nil cycle.return_to
    end

    test "return participant rejects protocol-relative return path" do
      actor = create_client
      cycle = create_cycle(actor, status_name: "RETURN_PENDING", return_to: "//evil.example/path")

      destination = ReturnParticipant.new(cycle: cycle, default_path: "/configuration").consume!

      assert_equal "/configuration", destination
      assert_predicate cycle.reload, :sign_in_completed?
      assert_nil cycle.return_to
    end

    test "post-issuance participants work for visitor and operator cycles" do
      [
        [VisitorSignInCycle, create_visitor],
        [OperatorSignInCycle, create_operator],
      ].each do |cycle_class, actor|
        cycle = create_cycle(actor, cycle_class: cycle_class, status_name: "CHECKPOINT_PENDING")

        CheckpointParticipant.new(cycle: cycle, actor: actor).advance_if_clear!
        DashboardParticipant.new(cycle: cycle.reload, actor: actor).advance!
        destination = ReturnParticipant.new(cycle: cycle.reload, default_path: "/configuration").consume!

        assert_equal "/dashboard", destination
        assert_predicate cycle.reload, :sign_in_completed?
      end
    end

    private

    def create_client
      Client.create!(public_id: "u_#{SecureRandom.hex(8)}", status_id: ClientStatus::ACTIVE)
    end

    def create_visitor
      Visitor.create!(public_id: "v_#{SecureRandom.hex(8)}", status_id: VisitorStatus::ACTIVE)
    end

    def create_operator
      Operator.create!(status_id: OperatorIdentityStatus::ACTIVE)
    end

    def create_cycle(actor, cycle_class: ClientSignInCycle, status_name:, return_to: "/dashboard")
      cycle_class.create!(
        principal_id: actor.id,
        status_id: cycle_class.status_id_for(status_name),
        step: step_for(status_name),
        return_to: return_to,
        nonce_digest: cycle_class.digest_nonce("nonce"),
        issued_at: Time.current,
        expires_at: 15.minutes.from_now,
      )
    end

    def step_for(status_name)
      {
        "CHECKPOINT_PENDING" => "checkpoint",
        "DASHBOARD_PENDING" => "dashboard",
        "RETURN_PENDING" => "return_to",
      }.fetch(status_name)
    end
  end
end
