# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Org::Settings::EntrasControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses, :operator_token_binding_methods,
           :operator_token_kinds, :operator_token_statuses, :operator_token_dbsc_statuses,
           :operator_mfa_levels, :operator_mfa_statuses, :operator_visibilities

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
    host! @host
    @operator = operators(:one)
    @operator.update!(status_id: OperatorStatus::ACTIVE)
    @token = OperatorToken.create!(staff: @operator, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    @token.rotate_refresh_token!
    @headers = {
      "Host" => @host,
      "X-TEST-CURRENT-STAFF" => @operator.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
      "Authorization" => "Bearer #{
        jwt_access_token_for(@operator, host: @host, session_public_id: @token.public_id, resource_type: "operator")
      }",
    }

    OrganizationEntraConnectionState.ensure_defaults!
    OperatorEntraIdentityState.ensure_defaults!
  end

  test "show is read only" do
    get auth_org_settings_entra_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_select "a[href=?]", auth_org_settings_path(ri: "jp")
    assert_select "a[href=?]", edit_auth_org_settings_entra_path(ri: "jp")
    assert_select "form[action=?]", auth_org_settings_entra_path(ri: "jp"), count: 0
  end

  test "edit offers existing Entra ceremony when an active connection exists" do
    connection = create_entra_connection!

    get edit_auth_org_settings_entra_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_select "form[action=?]", auth_org_settings_entra_path(ri: "jp")
    assert_includes response.body, connection.public_id
  end

  test "create redirects to the org Entra sign in ceremony" do
    connection = create_entra_connection!

    post auth_org_settings_entra_url(ri: "jp"),
         params: { entra: { connection_public_id: connection.public_id } },
         headers: @headers

    assert_response :see_other
    assert_equal(
      new_auth_org_sign_in_entra_url(ri: "jp", connection: connection.public_id),
      response.location,
    )
  end

  test "settings route uses create and destroy" do
    route = Rails.application.routes.recognize_path(
      "http://#{@host}/settings/entra",
      method: :post,
    )

    assert_equal "auth/org/settings/entras", route[:controller]
    assert_equal "create", route[:action]

    route = Rails.application.routes.recognize_path(
      "http://#{@host}/settings/entra",
      method: :delete,
    )

    assert_equal "auth/org/settings/entras", route[:controller]
    assert_equal "destroy", route[:action]
  end

  private

  def create_entra_connection!
    OrganizationEntraConnection.create!(
      organization_id: 1,
      entra_tenant_id: "11111111-2222-3333-4444-555555555555",
      entra_client_id: "settings-entras-controller-test-client",
      entra_credential_key: "settings-entras-controller-test-secret",
      status_id: OrganizationEntraConnectionState::ACTIVE,
    )
  end

  def jwt_access_token_for(resource, host:, session_public_id:, resource_type:)
    AuthenticationToken.encode(
      resource,
      host: host,
      session_public_id: session_public_id,
      resource_type: resource_type,
      jwt_issuer_id: "surface:SIGN_ORG",
    )
  end
end
