# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# Auth::App::Settings::ActivitiesController is a redirect shim to base/app/identity/activities.
class Auth::App::Settings::ActivitiesControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_token_kinds

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    @user = clients(:one)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    host! @host
  end

  test "sign settings activities redirects to base identity activities" do
    get auth_app_settings_activities_url(ri: "jp"), headers: session_headers

    assert_response :see_other
    assert_redirected_to base_app_identity_activities_path(ri: "jp")
  end

  private

  def session_headers
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
end
