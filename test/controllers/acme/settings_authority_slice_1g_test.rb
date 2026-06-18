# typed: false
# frozen_string_literal: true

require "test_helper"

class AcmeSettingsAuthoritySlice1GTest < ActionDispatch::IntegrationTest
  fixtures :clients, :operators, :client_statuses, :client_token_kinds, :client_token_statuses,
           :client_chronicle_events, :client_chronicle_levels

  test "acme app settings shell route is removed" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")}/settings",
        method: :get,
      )
    end
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

  test "acme com and org settings shell routes are removed" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")}/settings",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "http://#{ENV.fetch("ACME_STAFF_URL", "www.org.localhost")}/settings",
        method: :get,
      )
    end
  end

  private
end
