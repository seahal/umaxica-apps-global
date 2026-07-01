# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::Org::Settings::SessionsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses, :operator_token_kinds

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
    @staff = operators(:one)
    OperatorToken.where(staff: @staff).delete_all
    @current_token = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
  end

  test "index renders sign session inventory" do
    get auth_org_settings_sessions_url(ri: "jp"), headers: session_headers

    assert_response :success
    assert_includes response.body, @current_token.public_id
  end

  test "selected revocation revokes other session" do
    other_token = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)

    post auth_org_settings_session_revocation_url(other_token.public_id, ri: "jp"), headers: session_headers

    assert_redirected_to auth_org_settings_sessions_path(ri: "jp")
    assert_not_predicate other_token.reload, :currently_usable?
  end

  test "others revocation preserves current session" do
    other_token = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)

    post auth_org_settings_revocations_others_url(ri: "jp"), headers: session_headers

    assert_redirected_to auth_org_settings_sessions_path(ri: "jp")
    assert_predicate @current_token.reload, :currently_usable?
    assert_not_predicate other_token.reload, :currently_usable?
  end

  test "revoke all revokes every session" do
    other_token = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)

    post auth_org_settings_revocations_all_url(ri: "jp"), headers: session_headers

    assert_redirected_to auth_org_sign_out_path(ri: "jp")
    assert_not_predicate @current_token.reload, :currently_usable?
    assert_not_predicate other_token.reload, :currently_usable?
  end

  private

  def session_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-STAFF" => @staff.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @current_token.public_id,
      "Authorization" => "Bearer #{
        jwt_access_token_for(
          @staff, host: @host, session_public_id: @current_token.public_id, resource_type: "operator",
        )
      }",
    }
  end

  def jwt_access_token_for(resource, host: nil, session_id: nil, session_public_id: nil, resource_type: nil,
                           dpop_jkt: nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || "unknown"
    resource_type ||=
      case resource
      when Client then "client"
      when Operator then "operator"
      when Visitor then "visitor"
      end
    AuthenticationToken.encode(
      resource,
      host: host_value,
      session_id: session_id,
      session_public_id: session_public_id,
      resource_type: resource_type,
      dpop_jkt: dpop_jkt,
      jwt_issuer_id: jwt_issuer_id_for_test_host(host_value, resource_type),
    )
  end

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service = normalized.include?("acme") ? "ACME" : (normalized.include?("core") ? "CORE" : "SIGN")
    surface =
      if service == "SIGN"
        case resource_type
        when "operator" then "ORG"
        when "visitor" then "COM"
        else "APP"
        end
      elsif normalized.include?(".org") || normalized.include?("org.")
        "ORG"
      elsif normalized.include?(".com") || normalized.include?("com.")
        "COM"
      else
        "APP"
      end
    "surface:#{service}_#{surface}"
  end
end
