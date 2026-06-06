# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::App::SelectorControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
  end

  test "unauthenticated identity cannot access selector" do
    get acme_app_selector_url(host: @host), headers: host_headers(@host), as: :json

    assert_response :unauthorized
  end

  test "authenticated identity without selected actor context can access selector" do
    get acme_app_selector_url(host: @host), headers: as_user_headers(@user, host: @host), as: :json

    assert_response :success
    body = response.parsed_body

    assert_equal "selected", body.fetch("status")
    assert_predicate @token.reload, :selected_actor_context?
  end

  test "selector update persists valid selected actor context" do
    Acme::Selector::BootstrapAuthority.call(surface: :app, principal: @user)
    candidate = Acme::Selector::Authority.new(
      surface: :app, principal: @user,
      session: @token,
    ).selectable_candidates.first

    patch acme_app_selector_url(host: @host),
          params: candidate[:public],
          headers: as_user_headers(@user, host: @host, session_public_id: @token.public_id),
          as: :json

    assert_response :success
    assert_equal "selected", response.parsed_body.fetch("status")
    assert_equal candidate[:public][:account_public_id], @token.reload.selected_account_public_id
  end
end
