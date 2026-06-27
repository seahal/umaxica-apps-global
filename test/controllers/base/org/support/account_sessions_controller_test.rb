# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Org::Support::AccountSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("BASE_STAFF_URL", "www.org.localhost")
    @operator = operators(:one)
    @operator_token = OperatorToken.where(staff_id: @operator.id).first ||
      OperatorToken.create!(staff: @operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    mark_token_step_up_satisfied_for_test(@operator_token, scope: "session_revoke_all")
  end

  test "routes support session actions only on org host" do
    assert_routing(
      { method: :delete, path: "http://#{@host}/support/clients/#{clients(:one).id}/sessions/purge" },
      {
        controller: "base/org/support/clients/sessions",
        action: "purge",
        client_id: clients(:one).id.to_s,
      },
    )

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch(
          "BASE_SERVICE_URL",
          "www.app.localhost",
        )}/support/clients/#{clients(:one).id}/sessions/purge",
        method: :delete,
      )
    end
  end

  test "operator can purge client sessions" do
    client = clients(:one)
    AuthenticationSessionRevoker.tokens_for(client).find_each(&:revoke!)
    token = ClientToken.create!(user: client, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    delete(
      purge_base_org_support_client_session_url(client, host: @host),
      params: { reason_code: "security_incident", ticket_id: "SEC-635" },
      headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id),
      as: :json,
    )

    assert_response :ok
    body = response.parsed_body
    event = AccountAccessEvent.find(body.fetch("event_id"))

    assert_predicate token.reload, :revoked?
    assert_equal "ok", body.fetch("status")
    assert_equal AccountAccessEvent::EVENT_TYPE_SESSION_PURGE, body.fetch("event_type")
    assert_equal 1, body.fetch("revoked_count")
    assert_equal "SEC-635", event.ticket_id
  end

  test "operator can emergency revoke visitor sessions" do
    visitor = visitors(:reserved_visitor)
    token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)

    delete(
      emergency_revoke_base_org_support_visitor_session_url(visitor, host: @host),
      params: { reason_code: "security_incident" },
      headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id),
      as: :json,
    )

    assert_response :ok
    body = response.parsed_body

    assert_predicate token.reload, :revoked?
    assert_equal AccountAccessEvent::EVENT_TYPE_EMERGENCY_SESSION_REVOKE, body.fetch("event_type")
  end

  test "missing reason code returns unprocessable content" do
    delete(
      purge_base_org_support_client_session_url(clients(:one), host: @host),
      headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id),
      as: :json,
    )

    assert_response :unprocessable_content
    assert_equal "reason_code is invalid", response.parsed_body.fetch("error")
  end

  test "step-up is required" do
    @operator_token.update!(last_step_up_at: nil, last_step_up_scope: nil)

    delete(
      purge_base_org_support_client_session_url(clients(:one), host: @host),
      params: { reason_code: "security_incident" },
      headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id),
      as: :json,
    )

    assert_response :unprocessable_content
    assert_includes response.parsed_body.fetch("error"), "Step-up authentication required"
  end

  test "unknown target returns not found" do
    delete(
      purge_base_org_support_client_session_url(999_999, host: @host),
      params: { reason_code: "security_incident" },
      headers: as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id),
      as: :json,
    )

    assert_response :not_found
  end
end
