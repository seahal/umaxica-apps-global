# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::App::SwitchersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
  end

  test "unauthenticated identity cannot access switcher" do
    get base_app_switcher_url(host: @host), headers: host_headers(@host), as: :json

    assert_response :unauthorized
  end

  test "selector-only identity cannot access switcher" do
    get base_app_switcher_url(host: @host, ri: "jp"), headers: as_user_headers(@user, host: @host)

    assert_redirected_to base_app_selector_path(ri: "jp")
  end

  test "authenticated identity can access switcher show" do
    select_token!
    get base_app_switcher_url(host: @host), headers: as_user_headers(
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
    candidate = BaseSwitcherAuthority.new(
      surface: :app, principal: @user,
      session: @token,
    ).send(:selectable_candidates).first
    patch base_app_switcher_url(host: @host), headers: as_user_headers(
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
    candidate = BaseSwitcherAuthority.new(
      surface: :app, principal: @user,
      session: @token,
    ).send(:selectable_candidates).first

    patch base_app_switcher_url(host: @host, ri: "jp"), headers: as_user_headers(
      @user,
      host: @host,
      session_public_id: @token.public_id,
    ), params: candidate.fetch(:public)

    assert_redirected_to base_app_dashboard_path(ri: "jp")
    assert_predicate @token.reload, :selected_actor_context?
  end

  test "switcher update renders invalid switch error as json" do
    select_token!
    current_context = current_context_snapshot

    patch base_app_switcher_url(host: @host), headers: as_user_headers(
      @user,
      host: @host,
      session_public_id: @token.public_id,
    ), params: invalid_switch_params, as: :json

    assert_response :unprocessable_content
    assert_equal "invalid_switch", response.parsed_body.fetch("status")
    assert_context_unchanged!(current_context)
  end

  test "switcher update renders invalid switch error as html" do
    select_token!
    current_context = current_context_snapshot

    patch base_app_switcher_url(host: @host, ri: "jp"), headers: as_user_headers(
      @user,
      host: @host,
      session_public_id: @token.public_id,
    ), params: invalid_switch_params

    assert_response :unprocessable_content
    assert_context_unchanged!(current_context)
  end

  private

  def select_token!
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    BaseSelectorAuthority.prepare(surface: :app, principal: @user, session: @token)
  end

  def current_context_snapshot
    @token.reload.slice(
      "selected_account_public_id",
      "selected_collective_public_id",
      "selected_collective_unit_public_id",
      "selected_avatar_public_id",
    )
  end

  def assert_context_unchanged!(current_context)
    @token.reload

    assert_equal current_context["selected_account_public_id"], @token.selected_account_public_id
    assert_equal current_context["selected_collective_public_id"], @token.selected_collective_public_id
    assert_equal current_context["selected_collective_unit_public_id"], @token.selected_collective_unit_public_id
    assert_equal current_context["selected_avatar_public_id"], @token.selected_avatar_public_id
  end

  def invalid_switch_params
    candidate = BaseSwitcherAuthority.new(
      surface: :app, principal: @user,
      session: @token,
    ).send(:selectable_candidates).first

    candidate.fetch(:public).merge(avatar_public_id: "unknown-avatar")
  end
end
