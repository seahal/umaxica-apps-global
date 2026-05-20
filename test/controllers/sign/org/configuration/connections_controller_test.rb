# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Configuration::ConnectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    host! @host
    @staff = operators(:one)
    @current_token = create_staff_token!
    @current_token.update!(last_step_up_at: Time.current, last_step_up_scope: "configuration_connection")
    @headers = as_staff_headers(@staff, host: @host, session_public_id: @current_token.public_id)
    @connection = OperatorOidcConnection.create!(
      staff: @staff,
      client_id: "core_org",
      scope: "openid staff",
      last_used_at: 10.minutes.ago,
    )
    @rp_token = create_staff_token!(
      oidc_connection: @connection,
      oidc_client_id: "core_org",
      oidc_scope: "openid staff",
    )
  end

  test "index displays connected RP details" do
    get sign_org_configuration_connections_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_select "td", text: "Core Org"
    assert_select "td", text: /main\.org\.localhost/
    assert_select "td", text: /openid, staff/
  end

  test "show displays connection details" do
    get sign_org_configuration_connection_url(@connection.public_id, ri: "jp"), headers: @headers

    assert_response :success
    assert_select "dd", text: "core_org"
    assert_select "dd", text: "1"
  end

  test "index requires authentication" do
    get sign_org_configuration_connections_url(ri: "jp"), headers: host_headers(@host)

    assert_response :redirect
  end

  test "connection from another staff is not visible" do
    other = OperatorOidcConnection.create!(staff: operators(:two), client_id: "docs_org")

    get sign_org_configuration_connection_url(other.public_id, ri: "jp"), headers: @headers

    assert_response :not_found
  end

  test "destroy revokes connection and linked RP tokens" do
    delete sign_org_configuration_connection_url(@connection.public_id, ri: "jp"), headers: @headers

    assert_response :see_other
    assert_redirected_to sign_org_configuration_connections_url(ri: "jp")
    assert_predicate @connection.reload, :revoked?
    assert_predicate @rp_token.reload, :revoked?
    assert_not @current_token.reload.revoked?
  end

  private

  def create_staff_token!(attrs = {})
    token = OperatorToken.new(
      {
        staff: @staff,
        staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
        staff_token_status_id: OperatorTokenStatus::ACTIVE,
      }.merge(attrs),
    )
    token.send(:skip_session_limit_check=, true)
    token.save!
    token
  end
end
