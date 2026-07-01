# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::App::Settings::WithdrawalsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_tokens

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    host! @host
    @user = clients(:one)
    @token = client_tokens(:one)
  end

  def headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-USER" => @user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
      "Authorization" => "Bearer #{jwt_access_token_for(
        @user, host: @host, session_public_id: @token.public_id,
               resource_type: "client",
      )}",
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

  test "new redirects to base identity withdrawal" do
    get new_auth_app_settings_withdrawal_url(ri: "jp"), headers: headers

    assert_redirected_to new_base_app_identity_withdrawal_path(ri: "jp")
  end

  test "edit redirects to base identity withdrawal" do
    get edit_auth_app_settings_withdrawal_url(ri: "jp"), headers: headers

    assert_redirected_to edit_base_app_identity_withdrawal_path(ri: "jp")
  end

  test "create is gone" do
    post auth_app_settings_withdrawal_url(ri: "jp"), headers: headers

    assert_response :gone
  end

  test "update is gone" do
    patch auth_app_settings_withdrawal_url(ri: "jp"), headers: headers

    assert_response :gone
  end

  test "destroy is gone" do
    delete auth_app_settings_withdrawal_url(ri: "jp"), headers: headers

    assert_response :gone
  end
end
