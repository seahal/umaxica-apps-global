# typed: false
# frozen_string_literal: true

require "test_helper"

class AcmeSettingsAuthoritySlice1GTest < ActionDispatch::IntegrationTest
  fixtures :clients, :operators, :client_statuses, :client_token_kinds, :client_token_statuses,
           :client_chronicle_events, :client_chronicle_levels

  test "acme app settings shell renders account UI and keeps credential links on sign" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    user = clients(:one)
    user.update!(status_id: ClientStatus::ACTIVE)

    token = create_user_token!(user)
    select_token!(surface: :app, principal: user, token: token)

    get acme_app_settings_url(ri: "jp", host: host), headers: app_session_headers(host, token, user)

    assert_response :success
    assert_no_match(/id\.umaxica/, response.body)
    assert_select "a[href^=?]", sign_app_settings_passkeys_path(ri: "jp")
    assert_select "a[href^=?]", acme_app_settings_connections_path(ri: "jp")
    assert_select "a[href^=?]", acme_app_settings_activities_path
  end

  test "acme app activities list only current user entries" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    user = clients(:one)
    other_user = clients(:two)
    ChronicleRecord.connected_to(role: :writing) { ClientChronicle.delete_all }
    create_user_audit(user: user, tag: "my-login-event")
    create_user_audit(user: other_user, tag: "other-login-event")

    token = create_user_token!(user)
    select_token!(surface: :app, principal: user, token: token)

    get acme_app_settings_activities_url(ri: "jp", host: host), headers: app_session_headers(host, token, user)

    assert_response :success
    assert_no_match(/id\.umaxica/, response.body)
    assert_includes response.body, "my-login-event"
    assert_not_includes response.body, "other-login-event"
  end

  test "acme app connections index and show render from acme authority" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    user = clients(:one)
    token = create_user_token!(user)
    connection = ClientOidcConnection.create!(
      user: user,
      client_id: "core_app",
      scope: "openid profile",
    )

    get acme_app_settings_connections_url(ri: "jp", host: host), headers: app_session_headers(host, token, user)

    assert_response :success
    assert_no_match(/id\.umaxica/, response.body)
    assert_includes response.body, connection.rp_name
    assert_select "a[href=?]", acme_app_settings_path(ri: "jp")

    get acme_app_settings_connection_url(connection.public_id, ri: "jp", host: host),
        headers: app_session_headers(host, token, user)

    assert_response :success
    assert_no_match(/id\.umaxica/, response.body)
    assert_includes response.body, connection.client_id
    assert_select "a[href=?]", acme_app_settings_connections_path(ri: "jp")
  end

  test "acme app connection destroy revokes connection and linked downstream tokens" do
    host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    user = clients(:one)
    current_token = create_user_token!(user)
    mark_token_step_up_satisfied_for_test(current_token, scope: "settings_connection")
    connection = ClientOidcConnection.create!(user: user, client_id: "core_app", scope: "openid profile")
    rp_token = create_user_token!(
      user,
      oidc_connection: connection,
      oidc_client_id: "core_app",
      oidc_scope: "openid profile",
    )

    delete acme_app_settings_connection_url(connection.public_id, ri: "jp", host: host),
           headers: app_session_headers(host, current_token, user)

    assert_redirected_to acme_app_settings_connections_url(ri: "jp", host: host)
    assert_predicate connection.reload, :revoked?
    assert_predicate rp_token.reload, :revoked?
    assert_not_predicate current_token.reload, :revoked?
  end

  test "acme com and org settings shell routes exist" do
    visitor = create_verified_visitor_with_email(email_address: "settings-#{SecureRandom.hex(4)}@example.com")
    com_host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    visitor_token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    select_token!(surface: :com, principal: visitor, token: visitor_token)
    get acme_com_settings_url(ri: "jp", host: com_host), headers: com_session_headers(com_host, visitor_token, visitor)

    assert_response :success
    assert_no_match(/id\.umaxica/, response.body)

    staff = operators(:one)
    org_host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    staff_token = OperatorToken.create!(staff: staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    select_token!(surface: :org, principal: staff, token: staff_token)
    get acme_org_settings_url(ri: "jp", host: org_host), headers: org_session_headers(org_host, staff_token, staff)

    assert_response :success
    assert_no_match(/id\.umaxica/, response.body)
  end

  private

  def select_token!(surface:, principal:, token:)
    Acme::Selector::BootstrapAuthority.call(surface: surface, principal: principal)
    Acme::Selector::Authority.prepare(surface: surface, principal: principal, session: token)
  end

  def create_user_token!(user, attrs = {})
    token = ClientToken.new(
      {
        user: user,
        user_token_kind_id: ClientTokenKind::BROWSER_WEB,
        user_token_status_id: ClientTokenStatus::ACTIVE,
      }.merge(attrs),
    )
    token.send(:skip_session_limit_check=, true)
    token.save!
    token
  end

  def app_session_headers(host, token, user)
    {
      "Host" => host,
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end

  def com_session_headers(host, token, visitor)
    {
      "Host" => host,
      "X-TEST-CURRENT-RESOURCE" => visitor.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end

  def org_session_headers(host, token, staff)
    {
      "Host" => host,
      "X-TEST-CURRENT-STAFF" => staff.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end

  def create_user_audit(user:, tag:)
    ClientChronicle.create!(
      actor_type: "Client",
      actor_id: user.id,
      event_id: ClientChronicleEvent::LOGGED_IN,
      level_id: ClientChronicleLevel::NOTHING,
      subject_id: user.id,
      subject_type: "Client",
      occurred_at: Time.current,
      ip_address: "203.0.113.25",
      context: { tag: tag },
    )
  end
end
