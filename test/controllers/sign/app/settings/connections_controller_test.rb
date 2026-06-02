# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Settings::ConnectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    host! @host
    @user = clients(:one)
    @current_token = create_user_token!
    @current_token.update!(last_step_up_at: Time.current, last_step_up_scope: "settings_connection")
    mark_token_step_up_satisfied_for_test(@current_token, scope: "settings_connection")
    @headers = as_user_headers(@user, host: @host, session_public_id: @current_token.public_id)
    @connection = ClientOidcConnection.create!(
      user: @user,
      client_id: "core_app",
      scope: "openid profile",
      last_used_at: 10.minutes.ago,
    )
    @rp_token = create_user_token!(
      oidc_connection: @connection,
      oidc_client_id: "core_app",
      oidc_scope: "openid profile",
    )
  end

  test "index displays connected RP details" do
    get sign_app_settings_connections_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_select "td", text: "Core App"
    assert_select "td", text: /first_party_session/
    assert_select "td", text: /openid, profile/
    assert_select "a[href=?]", sign_app_settings_connection_path(@connection.public_id, ri: "jp")
  end

  test "show displays connection details" do
    get sign_app_settings_connection_url(@connection.public_id, ri: "jp"), headers: @headers

    assert_response :success
    assert_select "dd", text: "core_app"
    assert_select "dd", text: "1"
  end

  test "index requires authentication" do
    get sign_app_settings_connections_url(ri: "jp"), headers: host_headers(@host)

    assert_response :redirect
  end

  test "connection from another user is not visible" do
    other = ClientOidcConnection.create!(user: clients(:two), client_id: "docs_app")

    get sign_app_settings_connection_url(other.public_id, ri: "jp"), headers: @headers

    assert_response :not_found
  end

  test "destroy revokes connection and linked RP tokens" do
    delete sign_app_settings_connection_url(@connection.public_id, ri: "jp"), headers: @headers

    assert_response :see_other
    assert_redirected_to sign_app_settings_connections_url(ri: "jp")
    assert_predicate @connection.reload, :revoked?
    assert_predicate @rp_token.reload, :revoked?
    assert_not @current_token.reload.revoked?
  end

  test "destroy requires step up" do
    @current_token.update!(created_at: 1.hour.ago, last_step_up_at: nil, last_step_up_scope: nil)

    delete sign_app_settings_connection_url(@connection.public_id, ri: "jp"), headers: @headers

    assert_response :unauthorized
    assert_not @connection.reload.revoked?
    assert_not @rp_token.reload.revoked?
  end

  private

  def create_user_token!(attrs = {})
    token = ClientToken.new(
      {
        user: @user,
        user_token_kind_id: ClientTokenKind::BROWSER_WEB,
        user_token_status_id: ClientTokenStatus::ACTIVE,
      }.merge(attrs),
    )
    token.send(:skip_session_limit_check=, true)
    token.save!
    token
  end
end
