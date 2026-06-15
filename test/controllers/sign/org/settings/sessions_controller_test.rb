# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Settings::SessionsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses, :operator_token_kinds

  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @acme_host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    @staff = operators(:one)
    OperatorToken.where(staff: @staff).delete_all
    @current_token = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
  end

  test "index_redirects_to_acme_session_authority" do
    get sign_org_settings_sessions_url(ri: "jp"), headers: session_headers

    assert_redirect_to_acme_sessions
  end

  test "destroy_redirect_is_not_session_mutation" do
    other_token = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)

    post sign_org_settings_session_revocation_url(other_token.public_id, ri: "jp"), headers: session_headers

    assert_redirect_to_acme_sessions
    assert_predicate other_token.reload, :currently_usable?
  end

  test "others_redirect_is_not_session_inventory_mutation" do
    other_token = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)

    post sign_org_settings_revocations_others_url(ri: "jp"), headers: session_headers

    assert_redirect_to_acme_sessions
    assert_predicate other_token.reload, :currently_usable?
  end

  test "revoke_all_redirect_is_not_session_mutation" do
    other_token = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)

    post sign_org_settings_revocations_all_url(ri: "jp"), headers: session_headers

    assert_redirect_to_acme_sessions
    assert_predicate @current_token.reload, :currently_usable?
    assert_predicate other_token.reload, :currently_usable?
  end

  private

  def session_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-STAFF" => @staff.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @current_token.public_id,
    }
  end

  def assert_redirect_to_acme_sessions
    assert_response :see_other
    location = URI.parse(response.location)

    assert_equal @acme_host, location.host
    assert_equal "/settings/sessions", location.path
    assert_equal "ri=jp", location.query
  end
end
