# typed: false
# frozen_string_literal: true

require "test_helper"

module SignIn
  class SessionIssuerTest < ActiveSupport::TestCase
    test "issues client session once from session issuance pending cycle" do
      actor = create_client
      cycle = create_cycle(ClientSignInCycle, actor)

      result = SessionIssuer.new(cycle: cycle, actor: actor).call

      assert_instance_of ClientToken, result.token
      assert_equal result.token, result.cycle.token
      assert_equal actor.id, result.token.user_id
      assert_predicate result.refresh_token, :present?
      assert_predicate result.token.refresh_token_digest, :present?
      assert_predicate result.cycle, :sign_in_checkpoint_pending?
      assert_equal "checkpoint", result.cycle.step
      assert_nil result.token.last_step_up_at
      assert_nil result.token.last_step_up_scope
    end

    test "issues visitor and operator sessions on their own surfaces" do
      [
        [VisitorSignInCycle, create_visitor, VisitorToken, :visitor_id],
        [OperatorSignInCycle, create_operator, OperatorToken, :staff_id],
      ].each do |cycle_class, actor, token_class, foreign_key|
        cycle = create_cycle(cycle_class, actor)

        result = SessionIssuer.new(cycle: cycle, actor: actor).call

        assert_instance_of token_class, result.token
        assert_equal actor.id, result.token.public_send(foreign_key)
        assert_equal result.token, result.cycle.token
        assert_predicate result.cycle, :sign_in_checkpoint_pending?
      end
    end

    test "rejects cycle that is not at session issuance boundary without creating token" do
      actor = create_client
      cycle = create_cycle(ClientSignInCycle, actor, status_name: "GUARDRAIL_PENDING")

      assert_no_difference("ClientToken.count") do
        assert_raises(SessionIssuer::InvalidCycle) do
          SessionIssuer.new(cycle: cycle, actor: actor).call
        end
      end

      assert_predicate cycle.reload, :sign_in_guardrail_pending?
      assert_nil cycle.token_id
    end

    test "rejects replay when cycle already has token" do
      actor = create_client
      token = ClientToken.create!(user: actor)
      cycle = create_cycle(ClientSignInCycle, actor, token: token)

      assert_no_difference("ClientToken.count") do
        assert_raises(SessionIssuer::Replay) do
          SessionIssuer.new(cycle: cycle, actor: actor).call
        end
      end

      assert_predicate cycle.reload, :sign_in_session_issuance_pending?
      assert_equal token.id, cycle.token_id
    end

    test "rejects actor mismatch without mutating cycle" do
      actor = create_client
      other = create_client
      cycle = create_cycle(ClientSignInCycle, actor)

      assert_no_difference("ClientToken.count") do
        assert_raises(SessionIssuer::ActorMismatch) do
          SessionIssuer.new(cycle: cycle, actor: other).call
        end
      end

      assert_predicate cycle.reload, :sign_in_session_issuance_pending?
      assert_nil cycle.token_id
    end

    test "rolls back token creation when cycle transition fails" do
      actor = create_client
      cycle = create_cycle(ClientSignInCycle, actor)
      cycle.define_singleton_method(:advance_sign_in_to_checkpoint!) do
        raise ActiveRecord::RecordInvalid, self
      end

      assert_no_difference("ClientToken.count") do
        assert_raises(ActiveRecord::RecordInvalid) do
          SessionIssuer.new(cycle: cycle, actor: actor).call
        end
      end

      assert_predicate ClientSignInCycle.find(cycle.id), :sign_in_session_issuance_pending?
      assert_nil ClientSignInCycle.find(cycle.id).token_id
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

    def create_cycle(cycle_class, actor, status_name: "SESSION_ISSUANCE_PENDING", token: nil)
      cycle_class.create!(
        principal_id: actor.id,
        status_id: cycle_class.status_id_for(status_name),
        step: step_for(status_name),
        token: token,
        return_to: "/dashboard",
        nonce_digest: cycle_class.digest_nonce("nonce"),
        issued_at: Time.current,
        expires_at: 15.minutes.from_now,
      )
    end

    def step_for(status_name)
      {
        "GUARDRAIL_PENDING" => "guardrail",
        "SESSION_ISSUANCE_PENDING" => "session_issuance",
      }.fetch(status_name)
    end
  end
end
