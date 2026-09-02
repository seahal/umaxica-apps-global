# typed: false
# frozen_string_literal: true

require "test_helper"

# The staff Entra callback ends in one of four places depending on what the
# sign-in commit reported. Each has to be distinguishable: a terminal result is
# refused with its own status, a success continues the sign-in sequence, and
# anything else is recorded as a failed sign-in rather than quietly treated as
# one of the other three.
class Auth::Org::Omniauth::EntraSignInResultDispatchTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness < Auth::Org::Omniauth::OmniauthCallbacksController
    attr_reader :hard_reject, :sequence_pt, :entra_error, :failures, :redirected

    def initialize
      super
      @failures = []
    end

    def render_session_limit_hard_reject(message: nil, http_status: nil)
      @hard_reject = [message, http_status]
    end

    def redirect_to_sign_in_sequence!(pt: nil, **)
      @sequence_pt = pt
    end

    def redirect_to(*args, **kwargs)
      @redirected = [args, kwargs]
    end

    def render_entra_error(reason)
      @entra_error = reason
    end

    def log_entra_failure(event, **context)
      @failures << [event, context]
    end

    def invoke(name, ...) = send(name, ...)
  end

  def result(status:, message: nil, response_status: nil, redirect_to: nil)
    SignInResult.new(
      status: status,
      actor: nil,
      token: nil,
      sequence_id: nil,
      redirect_to: redirect_to,
      response_status: response_status,
      message: message,
    )
  end

  setup do
    @harness = Harness.new
  end

  test "a result that still needs a second factor follows the redirect it names" do
    @harness.invoke(
      :handle_sign_in_result,
      result(status: :mfa_required, redirect_to: "/sign/in/challenge"),
      pt: "/settings",
    )

    assert_equal [["/sign/in/challenge"], {}], @harness.redirected
  end

  test "a terminal result is refused with the status and message it carries" do
    @harness.invoke(
      :handle_sign_in_result,
      result(status: :session_limit_hard_reject, message: "too soon", response_status: :forbidden),
      pt: "/settings",
    )

    assert_equal ["too soon", :forbidden], @harness.hard_reject
  end

  test "a successful result continues the sign-in sequence at the requested target" do
    @harness.invoke(:handle_sign_in_result, result(status: :success), pt: "/settings")

    assert_equal "/settings", @harness.sequence_pt
  end

  test "any other result is recorded as a failed sign-in rather than passed through" do
    @harness.invoke(:handle_sign_in_result, result(status: :unknown_state), pt: "/settings")

    assert_equal :sign_in_failed, @harness.entra_error
    assert_equal "sign_in_failed", @harness.failures.first.first
  end
end
