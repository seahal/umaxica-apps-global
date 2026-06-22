# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::App::SwitcherControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
  end

  test "unauthenticated identity cannot access switcher" do
    get acme_app_switcher_url(host: @host), headers: host_headers(@host), as: :json

    assert_response :unauthorized
  end

  test "authenticated identity can access switcher show" do
    select_token!
    get acme_app_switcher_url(host: @host), headers: as_user_headers(
      @user,
      host: @host,
      session_public_id: @token.public_id,
    ), as: :json

    assert_response :success
    assert_equal "ok", response.parsed_body.fetch("status")
    assert_predicate @token.reload, :selected_actor_context?
  end

  test "authenticated identity can access switcher update" do
    select_token!
    candidate = AcmeSwitcherAuthority.new(
      surface: :app, principal: @user,
      session: @token,
    ).send(:selectable_candidates).first
    patch acme_app_switcher_url(host: @host), headers: as_user_headers(
      @user,
      host: @host,
      session_public_id: @token.public_id,
    ), params: candidate.fetch(:public), as: :json

    assert_response :success
    assert_equal "switched", response.parsed_body.fetch("status")
    assert_predicate @token.reload, :selected_actor_context?
  end

  test "switcher update follows html redirect on success" do
    select_token!
    candidate = AcmeSwitcherAuthority.new(
      surface: :app, principal: @user,
      session: @token,
    ).send(:selectable_candidates).first

    patch acme_app_switcher_url(host: @host, ri: "jp"), headers: as_user_headers(
      @user,
      host: @host,
      session_public_id: @token.public_id,
    ), params: candidate.fetch(:public)

    assert_redirected_to acme_app_dashboard_path(ri: "jp")
    assert_predicate @token.reload, :selected_actor_context?
  end

  test "switcher update renders invalid switch error as json" do
    select_token!

    patch acme_app_switcher_url(host: @host), headers: as_user_headers(
      @user,
      host: @host,
      session_public_id: @token.public_id,
    ), params: { account_public_id: "unknown-account" }, as: :json

    assert_response :unprocessable_content
    assert_equal "invalid_switch", response.parsed_body.fetch("status")
  end

  test "switcher update renders invalid switch error as html" do
    select_token!

    patch acme_app_switcher_url(host: @host, ri: "jp"), headers: as_user_headers(
      @user,
      host: @host,
      session_public_id: @token.public_id,
    ), params: { account_public_id: "unknown-account" }

    assert_response :unprocessable_content
  end

  private

  def select_token!
    AcmeSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    AcmeSelectorAuthority.prepare(surface: :app, principal: @user, session: @token)
  end
end
