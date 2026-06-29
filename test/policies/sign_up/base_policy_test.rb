# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignUp::BasePolicyTest < ActiveSupport::TestCase
  class FakeTicket
    attr_reader :public_id, :status_id, :principal_id, :step

    def initialize(public_id:, status_id:, principal_id: nil, step: nil)
      @public_id = public_id
      @status_id = status_id
      @principal_id = principal_id
      @step = step
    end

    def status_id_for(name)
      raise KeyError, name if name == "COMPLETED"

      1
    end
  end

  test "surface_matches? returns false when the registry cannot resolve the ticket" do
    ticket = FakeTicket.new(public_id: "x", status_id: 10)
    record = Struct.new(:ticket).new(ticket)
    policy = SignUp::BasePolicy.new(record, user: nil)

    assert_not policy.send(:surface_matches?)
  end

  test "terminal_status_ids tolerates missing terminal status mappings" do
    ticket = FakeTicket.new(public_id: "x", status_id: 10)
    record = Struct.new(:ticket).new(ticket)
    policy = SignUp::BasePolicy.new(record, user: nil)

    assert_equal [1, 1, 1], policy.send(:terminal_status_ids)
  end

  test "pending_actor_matches? links a signed-out user to the ticket principal" do
    ClientSignUpFlowStatus.ensure_defaults!
    client = Client.new(id: 42)
    flow = ClientSignUpFlow.new
    flow.principal_id = 42

    policy = SignUp::BasePolicy.new(flow, user: client)

    assert policy.send(:pending_actor_matches?)
  end

  test "actor_class_matches? recognizes client and visitor sign-up flows" do
    client_flow = ClientSignUpFlow.new
    visitor_flow = VisitorSignUpFlow.new
    other_flow = OperatorSignUpFlow.new

    assert SignUp::BasePolicy.new(client_flow, user: Client.new).send(:actor_class_matches?)
    assert SignUp::BasePolicy.new(visitor_flow, user: Visitor.new).send(:actor_class_matches?)
    assert_not SignUp::BasePolicy.new(other_flow, user: Client.new).send(:actor_class_matches?)
  end
end
