# typed: false
# frozen_string_literal: true

require "test_helper"

class Side::App::RootsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses

  setup do
    @host = ENV.fetch("PUBLIC_SIDE_SERVICE_URL")
    @user = clients(:one)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    satisfy_user_verification(@token)
  end

  test "renders anonymous root" do
    host! @host

    get side_app_root_url(ri: "jp")

    assert_response :success
    assert_select "h1", text: "Side App"
  end

  test "redirects signed-in client to dashboard" do
    host! @host

    get side_app_root_url(ri: "jp"), headers: as_user_headers(@user, host: @host, session_public_id: @token.public_id)

    assert_response :redirect
    assert_redirected_to side_app_dashboard_url(ri: "jp", host: @host)
  end
end
