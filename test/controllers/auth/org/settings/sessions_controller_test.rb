# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Org::Settings::SessionsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses, :operator_token_kinds

  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = operators(:one)
    OperatorToken.where(staff: @staff).delete_all
    @current_token = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
  end

  test "index renders sign session inventory" do
    get sign_org_settings_sessions_url(ri: "jp"), headers: session_headers

    assert_response :success
    assert_includes response.body, @current_token.public_id
  end

  test "selected revocation revokes other session" do
    other_token = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)

    post sign_org_settings_session_revocation_url(other_token.public_id, ri: "jp"), headers: session_headers

    assert_redirected_to sign_org_settings_sessions_path(ri: "jp")
    assert_not_predicate other_token.reload, :currently_usable?
  end

  test "others revocation preserves current session" do
    other_token = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)

    post sign_org_settings_revocations_others_url(ri: "jp"), headers: session_headers

    assert_redirected_to sign_org_settings_sessions_path(ri: "jp")
    assert_predicate @current_token.reload, :currently_usable?
    assert_not_predicate other_token.reload, :currently_usable?
  end

  test "revoke all revokes every session" do
    other_token = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)

    post sign_org_settings_revocations_all_url(ri: "jp"), headers: session_headers

    assert_redirected_to sign_org_sign_out_path(ri: "jp")
    assert_not_predicate @current_token.reload, :currently_usable?
    assert_not_predicate other_token.reload, :currently_usable?
  end

  private

  def session_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-STAFF" => @staff.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @current_token.public_id,
    }
  end
end
