# typed: false
# frozen_string_literal: true

require "test_helper"

class SignIn::ResultTest < ActiveSupport::TestCase
  fixtures_none!

  test "maps successful session hash to common result" do
    result = SignIn::Result.from_session_result(
      {
        status: :success,
        access_token: "access",
        token_type: "Bearer",
        expires_in: 3600,
      },
      actor: "actor",
      sequence_id: "sequence",
    )

    assert_predicate result, :success?
    assert_equal "actor", result.actor
    assert_equal "sequence", result.sequence_id
    assert_equal "access", result.token.fetch(:access_token)
    assert_equal :found, result.response_status
  end

  test "maps mfa required to redirect result" do
    result = SignIn::Result.from_session_result(
      { status: :mfa_required, redirect_path: "/mfa" },
    )

    assert_predicate result, :mfa_required?
    assert_equal "/mfa", result.redirect_to
    assert_equal :found, result.response_status
  end

  test "maps restricted session to session limit pending" do
    result = SignIn::Result.from_session_result(
      { status: :success, restricted: true },
      session_management_path: "/in/session",
    )

    assert_predicate result, :session_limit_pending?
    assert_equal "/in/session", result.redirect_to
    assert_equal :found, result.response_status
  end

  test "maps legacy session limit exceeded to session limit pending" do
    result = SignIn::Result.from_session_result(
      { status: :session_limit_exceeded },
      session_management_path: "/in/session",
    )

    assert_predicate result, :session_limit_pending?
    assert_equal "/in/session", result.redirect_to
    assert_equal :found, result.response_status
  end

  test "maps hard reject to terminal forbidden result" do
    result = SignIn::Result.from_session_result(
      { status: :session_limit_hard_reject, message: "full" },
    )

    assert_predicate result, :terminal?
    assert_equal :session_limit_hard_reject, result.status
    assert_equal :forbidden, result.response_status
    assert_equal "full", result.message
  end

  test "maps unknown session hash to invalid request" do
    result = SignIn::Result.from_session_result({})

    assert_predicate result, :terminal?
    assert_equal :invalid_request, result.status
    assert_equal :bad_request, result.response_status
  end
end
