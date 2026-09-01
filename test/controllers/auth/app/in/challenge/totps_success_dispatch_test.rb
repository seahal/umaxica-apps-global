# typed: false
# frozen_string_literal: true

require "test_helper"

# A verified second factor still has to be committed as a session, and the
# commit can report four different outcomes. Each is answered distinctly: a
# session-limit refusal keeps its own status, a restricted session goes to the
# session management page, a success continues the sequence, and anything else
# returns to the entry point rather than being treated as a login.
class AuthAppInChallengeTotpsSuccessDispatchTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness < Auth::App::Sign::In::Challenge::TotpsController
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
  end

  setup do
    @harness = Harness.new
    @harness.params_hash = { ri: "jp" }
    @harness.request = ActionDispatch::TestRequest.create
  end

  test "a session-limit refusal keeps the status and message the commit reported" do
    @harness.finalize_result = { status: :session_limit_hard_reject, message: "too many", http_status: :forbidden }

    @harness.invoke(:handle_totp_success, nil)

    assert_equal ["too many", :forbidden], @harness.hard_reject
  end

  test "a restricted session is sent to the destination the commit named" do
    @harness.finalize_result = { status: :restricted, redirect_path: "/in/session" }

    @harness.invoke(:handle_totp_success, nil)

    assert_equal [["/in/session"], {}], @harness.redirected
  end

  test "a successful commit continues the sign-in sequence" do
    @harness.finalize_result = { status: :success, redirect_path: "/settings" }

    @harness.invoke(:handle_totp_success, nil)

    assert_equal "/settings", @harness.sequence_pt
  end

  test "any other outcome returns to the sign-in entry point" do
    @harness.finalize_result = { status: :unknown_state }

    @harness.invoke(:handle_totp_success, nil)

    assert_includes @harness.redirected.first.first, "/sign/in"
  end
end
