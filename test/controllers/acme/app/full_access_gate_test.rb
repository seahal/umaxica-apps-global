# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::App::FullAccessGateTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
  end

  test "dashboard redirects authenticated unselected session to selector" do
    get acme_app_dashboard_url(host: @host, ri: "jp"), headers: as_user_headers(@user, host: @host)

    assert_redirected_to acme_app_selector_path(ri: "jp")
  end

  test "dashboard renders after selector persists context" do
    AcmeSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    AcmeSelectorAuthority.prepare(surface: :app, principal: @user, session: @token)

    get acme_app_dashboard_url(host: @host, ri: "jp"), headers: as_user_headers(
      @user,
      host: @host,
      session_public_id: @token.public_id,
    )

    assert_response :success
  end
end
