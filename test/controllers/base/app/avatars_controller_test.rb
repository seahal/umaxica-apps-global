# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::App::AvatarsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("BASE_SERVICE_URL")
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
  end

  test "unauthenticated cannot access avatars" do
    get base_app_avatars_url(ri: "jp", host: @host), headers: host_headers(@host)

    assert_response :redirect
    assert_oidc_authorize_redirect(response.location, host: @host)
  end

  test "selector-only (no selected context) cannot access avatars" do
    get base_app_avatars_url(ri: "jp", host: @host), headers: as_user_headers(@user, host: @host)

    assert_response :redirect
    assert_match(%r{/selector}, response.location)
  end

  test "full login can list avatars" do
    bootstrap_and_select!(@user, @token)

    get base_app_avatars_url(ri: "jp", host: @host), headers: as_user_headers(@user, host: @host)

    assert_response :success
  end

  test "full login can show, edit and update own avatar" do
    result = bootstrap_and_select!(@user, @token)

    get base_app_avatar_url(result.avatar.public_id, ri: "jp", host: @host),
        headers: as_user_headers(@user, host: @host)

    assert_response :success

    get edit_base_app_avatar_url(result.avatar.public_id, ri: "jp", host: @host),
        headers: as_user_headers(@user, host: @host)

    assert_response :success

    patch base_app_avatar_url(result.avatar.public_id, ri: "jp", host: @host),
          headers: as_user_headers(@user, host: @host)

    assert_response :see_other
  end

  test "new avatar form renders" do
    bootstrap_and_select!(@user, @token)

    get new_base_app_avatar_url(ri: "jp", host: @host), headers: as_user_headers(@user, host: @host)

    assert_response :success
  end

  test "create avatar redirects" do
    bootstrap_and_select!(@user, @token)

    post base_app_avatars_url(ri: "jp", host: @host), headers: as_user_headers(@user, host: @host)

    assert_response :see_other
    assert_redirected_to base_app_avatars_url(ri: "jp", host: @host)
  end

  test "cannot show another client's avatar" do
    bootstrap_and_select!(@user, @token)
    other_avatar = bootstrap_other_client.avatar

    get base_app_avatar_url(other_avatar.public_id, ri: "jp", host: @host),
        headers: as_user_headers(@user, host: @host)

    assert_response :not_found
  end

  test "cannot update another client's avatar" do
    bootstrap_and_select!(@user, @token)
    other_avatar = bootstrap_other_client.avatar

    patch base_app_avatar_url(other_avatar.public_id, ri: "jp", host: @host),
          headers: as_user_headers(@user, host: @host)

    assert_response :not_found
  end

  private

  def bootstrap_and_select!(user, token)
    result = BaseSelectorBootstrapAuthority.call(surface: :app, principal: user)
    BaseSelectorAuthority.prepare(surface: :app, principal: user, session: token)
    result
  end

  def bootstrap_other_client
    other = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: other)
  end
end
