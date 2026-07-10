# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module SignIn
  class PostIssuanceParticipantsTest < ActiveSupport::TestCase
    test "empty checkpoint stack advances to selector" do
      actor = create_client
      cycle = create_cycle(actor, status_name: "CHECKPOINT_PENDING")

      result = SignInCheckpointParticipant.new(cycle: cycle, actor: actor).advance_if_clear!

      assert_predicate result, :empty?
      assert_predicate result, :cleared?
      assert_predicate cycle.reload, :sign_in_selector_pending?
      assert_equal "selector", cycle.step
    end

    test "checkpoint evaluator must return SignInParticipantItem" do
      actor = create_client
      cycle = create_cycle(actor, status_name: "CHECKPOINT_PENDING")
      evaluator = lambda { |**| "not-an-item" }

      assert_raises ArgumentError do
        SignInCheckpointParticipant.new(cycle: cycle, actor: actor, evaluators: [evaluator]).evaluate
      end
    end

    test "dashboard evaluator must return SignInParticipantItem" do
      actor = create_client
      cycle = create_cycle(actor, status_name: "DASHBOARD_PENDING")
      evaluator = lambda { |**| "not-an-item" }

      assert_raises ArgumentError do
        SignInDashboardParticipant.new(cycle: cycle, actor: actor, evaluators: [evaluator]).evaluate
      end
    end

    test "resolver with no resolved actor returns empty candidates" do
      cycle = Object.new
      cycle.singleton_class.class_eval do
        def principal
          nil
        end
      end
      resolver = SignInActivationCandidateResolver.new(cycle: cycle, actor: nil)

      assert_empty resolver.candidates
    end

    test "resolver falls back to default region on error" do
      actor = create_client
      # Stub preference/region lookup to raise StandardError
      actor.singleton_class.class_eval do
        def preferences
          raise StandardError, "DB error"
        end
      end
      resolver = SignInActivationCandidateResolver.new(cycle: nil, actor: actor)
      candidates = resolver.candidates

      assert_equal 1, candidates.size
      assert_equal "jp", candidates.first.region
      assert_equal "Client", candidates.first.persona
    end

    test "blocking checkpoint item keeps cycle at checkpoint" do
      actor = create_client
      cycle = create_cycle(actor, status_name: "CHECKPOINT_PENDING")
      evaluator =
        lambda do |**|
          SignInParticipantItem.new(key: :bulletin, blocking: true, cleared: false)
        end

      result = SignInCheckpointParticipant.new(cycle: cycle, actor: actor, evaluators: [evaluator]).advance_if_clear!

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
          SignInParticipantItem.new(key: :welcome, blocking: false, cleared: false)
        end

      result = SignInDashboardParticipant.new(cycle: cycle, actor: actor, evaluators: [evaluator]).advance!

      assert_not_predicate result, :blocking?
      assert_equal [:welcome], result.stack.map(&:key)
      assert_predicate cycle.reload, :sign_in_return_pending?
      assert_equal "return_to", cycle.step
    end

    test "selector auto-commits a single candidate to session issuance under cycle lock" do
      actor = create_client
      cycle = create_cycle(actor, status_name: "SELECTOR_PENDING")

      result = SignInSelectorParticipant.new(
        cycle: cycle,
        actor: actor,
      ).auto_commit_single!

      assert_equal :auto_committed, result.status
      assert_equal "Client", result.candidate.persona
      assert_predicate cycle.reload, :sign_in_session_issuance_pending?
      assert_equal "session_issuance", cycle.step
      assert_not_nil cycle.selector_completed_at if cycle.has_attribute?(:selector_completed_at)
    end

    test "selector rejects non-selector cycle without advancing" do
      actor = create_client
      cycle = create_cycle(actor, status_name: "CHECKPOINT_PENDING")

      assert_raises SignInSelectorParticipant::InvalidCycle do
        SignInSelectorParticipant.new(cycle: cycle, actor: actor).auto_commit_single!
      end
      assert_predicate cycle.reload, :sign_in_checkpoint_pending?
    end

    test "selector rejects mismatched actor binding" do
      actor = create_client
      cycle = create_cycle(actor, status_name: "SELECTOR_PENDING")

      assert_raises SignInSelectorParticipant::InvalidCycle do
        SignInSelectorParticipant.new(cycle: cycle, actor: create_client).auto_commit_single!
      end
      assert_predicate cycle.reload, :sign_in_selector_pending?
    end

    test "selector rejects unknown cycle class as actor class mismatch" do
      actor = create_client
      cycle = Object.new
      cycle.singleton_class.class_eval do
        define_method(:sign_in_selector_pending?) { true }
        define_method(:expired?) { false }
        define_method(:principal_id) { actor.id }
        define_method(:principal) { actor }
        define_method(:class) do
          Class.new do
            def self.transaction
              yield
            end
          end
        end
        define_method(:lock!) { nil }
      end

      assert_raises SignInSelectorParticipant::InvalidCycle do
        SignInSelectorParticipant.new(cycle: cycle, actor: actor).auto_commit_single!
      end
    end

    test "legacy return participant consumes safe return path and completes cycle" do
      actor = create_client
      cycle = create_cycle(actor, status_name: "RETURN_PENDING", return_to: "/settings?tab=sessions")

      destination = SignInReturnParticipant.new(cycle: cycle, default_path: "/settings").consume!

      assert_equal "/settings?tab=sessions", destination
      assert_predicate cycle.reload, :sign_in_completed?
      assert_equal "completed", cycle.step
      assert_not_nil cycle.completed_at
      assert_nil cycle.return_to
    end

    test "legacy return participant discards unsafe return path and completes cycle with default" do
      actor = create_client
      cycle = create_cycle(actor, status_name: "RETURN_PENDING", return_to: "https://evil.example/path")

      destination = SignInReturnParticipant.new(cycle: cycle, default_path: "/settings").consume!

      assert_equal "/settings", destination
      assert_predicate cycle.reload, :sign_in_completed?
      assert_nil cycle.return_to
    end

    test "legacy return participant rejects protocol-relative return path" do
      actor = create_client
      cycle = create_cycle(actor, status_name: "RETURN_PENDING", return_to: "//evil.example/path")

      destination = SignInReturnParticipant.new(cycle: cycle, default_path: "/settings").consume!

      assert_equal "/settings", destination
      assert_predicate cycle.reload, :sign_in_completed?
      assert_nil cycle.return_to
    end

    test "checkpoint and selector participants work for visitor and operator cycles" do
      [
        [VisitorSignInFlow, create_visitor],
        [OperatorSignInFlow, create_operator],
      ].each do |cycle_class, actor|
        cycle = create_cycle(actor, cycle_class: cycle_class, status_name: "CHECKPOINT_PENDING")

        SignInCheckpointParticipant.new(cycle: cycle, actor: actor).advance_if_clear!
        SignInSelectorParticipant.new(cycle: cycle.reload, actor: actor).auto_commit_single!
        cycle.reload.complete_sign_in!

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
      Operator.create!(status_id: OperatorStatus::ACTIVE)
    end

    def create_cycle(actor, cycle_class: ClientSignInFlow, status_name:, return_to: "/dashboard")
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
        "SELECTOR_PENDING" => "selector",
        "SESSION_ISSUANCE_PENDING" => "session_issuance",
        "DASHBOARD_PENDING" => "dashboard",
        "RETURN_PENDING" => "return_to",
      }.fetch(status_name)
    end
  end
end
