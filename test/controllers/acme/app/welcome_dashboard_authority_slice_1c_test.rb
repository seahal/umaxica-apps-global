# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::App::WelcomeDashboardAuthoritySlice1CTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses

  setup do
    @host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    @user = clients(:one)
    @user.update!(status_id: ClientStatus::ACTIVE)
  end

  test "dashboard_requires_authentication" do
    get acme_app_dashboard_url(ri: "jp"), headers: host_headers(@host)

    assert_response :redirect
  end

  test "dashboard_renders_when_signed_in" do
    token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    get acme_app_dashboard_url(ri: "jp"), headers: session_headers(token)

    assert_response :success
    assert_select "h1", "Dashboard"
    assert_no_match(/id\.umaxica/, response.body)
    assert_select "a[href=?]", acme_app_settings_path(ri: "jp")
  end

  test "welcome_requires_authentication" do
    get acme_app_welcome_entry_url(ri: "jp"), headers: host_headers(@host)

    assert_response :redirect
  end

  private

  def session_headers(token)
    {
      "Host" => @host,
      "X-TEST-CURRENT-USER" => @user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end
end
