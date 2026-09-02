# typed: false
# frozen_string_literal: true

require "test_helper"

# Completing a passkey second factor commits a session, and the commit reports
# one of four outcomes. Each surface answers all four the same way, and each
# answer is distinct: a refusal keeps its own status, a restricted session goes
# to session management, a success continues the sequence, and anything else
# returns to that surface's sign-in entry point.
class Auth::ChallengePasskeyLoginDispatchTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness_for(controller_class)
    Class.new(controller_class) do
      attr_accessor :params_hash, :finalize_result, :hard_reject, :redirected, :sequence_pt

      def params
        ActionController::Parameters.new(params_hash || {})
      end

      def finalize_mfa_login!(_user) = finalize_result

      def render_session_limit_hard_reject(message: nil, http_status: nil)
        self.hard_reject = [message, http_status]
      end

      def redirect_to(*args, **kwargs)
        self.redirected = [args, kwargs]
      end

      def redirect_to_sign_in_sequence!(pt: nil, **)
        self.sequence_pt = pt
      end

      def invoke(name, ...) = send(name, ...)
    end.new.tap do |h|
      h.params_hash = { ri: "jp" }
      h.request = ActionDispatch::TestRequest.create
    end
  end

  [
    Auth::App::Sign::In::Challenge::PasskeysController,
    Auth::Com::Sign::In::Challenge::PasskeysController,
    Auth::Org::Sign::In::Challenge::PasskeysController,
  ].each do |klass|
    test "#{klass.name} answers each commit outcome distinctly" do
      refused = harness_for(klass)
      refused.finalize_result = { status: :session_limit_hard_reject, message: "too many", http_status: :forbidden }
      refused.invoke(:complete_mfa_login!, nil)

      assert_equal ["too many", :forbidden], refused.hard_reject

      restricted = harness_for(klass)
      restricted.finalize_result = { status: :restricted, redirect_path: "/in/session" }
      restricted.invoke(:complete_mfa_login!, nil)

      assert_equal [["/in/session"], {}], restricted.redirected

      succeeded = harness_for(klass)
      succeeded.finalize_result = { status: :success, redirect_path: "/settings" }
      succeeded.invoke(:complete_mfa_login!, nil)

      assert_equal "/settings", succeeded.sequence_pt

      unknown = harness_for(klass)
      unknown.finalize_result = { status: :unknown_state }
      unknown.invoke(:complete_mfa_login!, nil)

      assert_includes unknown.redirected.first.first, "/sign/in"
    end
  end
end
