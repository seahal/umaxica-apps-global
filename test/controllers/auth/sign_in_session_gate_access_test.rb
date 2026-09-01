# typed: false
# frozen_string_literal: true

require "test_helper"

# The session-management page is reachable while a sign-in is parked at the
# limit, which is a state the ordinary authentication check would refuse. A
# valid gate together with the pending principal is what proves the request
# belongs to that flow, and the staff surface resolves that principal from the
# gate when there is no signed-in operator yet.
class Auth::SignInSessionGateAccessTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness_for(controller_class, &definition)
    Class.new(controller_class) do
      attr_accessor :params_hash

      def params
        ActionController::Parameters.new(params_hash || {})
      end

      def session = @session_hash ||= {}

      def pending_session_limit_cycle? = false

      def invoke(name, ...) = send(name, ...)

      class_eval(&definition) if definition
    end.new.tap do |h|
      h.params_hash = { ri: "jp" }
      h.request = ActionDispatch::TestRequest.create
    end
  end

  test "a valid gate together with the pending client admits the request" do
    harness =
      harness_for(Auth::App::Sign::In::SessionsController) do
        def session_limit_gate_valid? = true

        def logged_in? = false
      end
    harness.session[:pending_login_user_id] = 42

    assert_nil harness.invoke(:require_authentication_or_gate)
  end

  test "the staff surface resolves the pending operator from the gate when none is signed in" do
    operator = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    harness =
      harness_for(Auth::Org::Sign::In::SessionsController) do
        def current_resource = nil
      end
    harness.session[:pending_login_staff_id] = operator.id

    assert_equal operator, harness.invoke(:resolve_current_operator)
  end

  test "the staff surface resolves no operator when the gate names none" do
    harness =
      harness_for(Auth::Org::Sign::In::SessionsController) do
        def current_resource = nil
      end

    assert_nil harness.invoke(:resolve_current_operator)
  end
end
