# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class Base::App::FullAccessGateTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
  end

  test "dashboard redirects authenticated unselected session to selector" do
    get base_app_dashboard_url(host: @host, ri: "jp"), headers: as_user_headers(@user, host: @host)

    assert_redirected_to base_app_selector_path(ri: "jp")
  end

  test "dashboard renders after selector persists context" do
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    BaseSelectorAuthority.prepare(surface: :app, principal: @user, session: @token)

    get base_app_dashboard_url(host: @host, ri: "jp"), headers: as_user_headers(
      @user,
      host: @host,
      session_public_id: @token.public_id,
    )

    assert_response :success
  end

  test "dashboard requests selection as json when context is missing" do
    get base_app_dashboard_url(host: @host, ri: "jp"), headers: as_user_headers(
      @user,
      host: @host,
    ), as: :json

    assert_response :forbidden
    assert_equal "selection_required", response.parsed_body.fetch("status")
  end
end
