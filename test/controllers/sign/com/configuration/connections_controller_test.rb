# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Configuration::ConnectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    host! @host
    ensure_visitor_references!
    @visitor = Visitor.create!(
      status_id: VisitorStatus::ACTIVE,
      visibility_id: VisitorVisibility::VISITOR,
    )
    VisitorEmail.create!(
      visitor: @visitor,
      address: "connection-#{SecureRandom.hex(4)}@example.com",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      confirm_policy: "1",
    )
    @visitor.visitor_telephones.create!(
      number: "+819000001234",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    @current_token = create_visitor_token!
    @current_token.update!(last_step_up_at: Time.current, last_step_up_scope: "configuration_connection")
    mark_token_step_up_satisfied_for_test(@current_token, scope: "configuration_connection")
    @headers = as_visitor_headers(@visitor, host: @host, session_public_id: @current_token.public_id)
    @connection = VisitorOidcConnection.create!(
      visitor: @visitor,
      client_id: "core_com",
      scope: "openid visitor",
      last_used_at: 10.minutes.ago,
    )
    @rp_token = create_visitor_token!(
      oidc_connection: @connection,
      oidc_client_id: "core_com",
      oidc_scope: "openid visitor",
    )
  end

  test "index displays connected RP details" do
    get sign_com_configuration_connections_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_select "td", text: "Core Com"
    assert_select "td", text: /first_party_session/
    assert_select "td", text: /openid, visitor/
  end

  test "show displays connection details" do
    get sign_com_configuration_connection_url(@connection.public_id, ri: "jp"), headers: @headers

    assert_response :success
    assert_select "dd", text: "core_com"
    assert_select "dd", text: "1"
  end

  test "index requires authentication" do
    get sign_com_configuration_connections_url(ri: "jp"), headers: host_headers(@host)

    assert_response :redirect
  end

  test "connection from another visitor is not visible" do
    other_visitor = Visitor.create!(
      status_id: VisitorStatus::ACTIVE,
      visibility_id: VisitorVisibility::VISITOR,
    )
    other = VisitorOidcConnection.create!(visitor: other_visitor, client_id: "docs_com")

    get sign_com_configuration_connection_url(other.public_id, ri: "jp"), headers: @headers

    assert_response :not_found
  end

  test "destroy revokes connection and linked RP tokens" do
    delete sign_com_configuration_connection_url(@connection.public_id, ri: "jp"), headers: @headers

    assert_response :see_other
    assert_redirected_to sign_com_configuration_connections_url(ri: "jp")
    assert_predicate @connection.reload, :revoked?
    assert_predicate @rp_token.reload, :revoked?
    assert_not @current_token.reload.revoked?
  end

  private

  def ensure_visitor_references!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::ACTIVE)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.ensure_defaults!
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::NOTHING)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
  end

  def create_visitor_token!(attrs = {})
    token = VisitorToken.new(
      {
        visitor: @visitor,
        visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
        visitor_token_status_id: VisitorTokenStatus::ACTIVE,
        visitor_token_binding_method_id: VisitorTokenBindingMethod::NOTHING,
        visitor_token_dbsc_status_id: VisitorTokenDbscStatus::NOTHING,
      }.merge(attrs),
    )
    token.send(:skip_session_limit_check=, true)
    token.save!
    token
  end
end
