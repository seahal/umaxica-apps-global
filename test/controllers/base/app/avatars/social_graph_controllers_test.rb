# typed: false
# frozen_string_literal: true

require "test_helper"

# Follow / block / mute edges between avatars on the app surface. Each edge has
# its own controller pair (create + destroy); all six are asserted through the
# routed endpoints with a fully selected actor context.
class Base::App::Avatars::SocialGraphControllersTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! @host
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    @actor_avatar = BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user).avatar
    BaseSelectorAuthority.prepare(surface: :app, principal: @user, session: @token)

    other = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @target_avatar = BaseSelectorBootstrapAuthority.call(surface: :app, principal: other).avatar
  end

  test "create follow records the edge from the selected avatar to the target" do
    assert_difference("AvatarFollow.count", 1) do
      post base_app_avatar_follow_url(@target_avatar.public_id, ri: "jp", host: @host),
           headers: as_user_headers(@user, host: @host)
    end

    assert_response :created
    assert_predicate response.parsed_body.fetch("public_id"), :present?
    assert AvatarFollow.exists?(follower_avatar: @actor_avatar, followed_avatar: @target_avatar)
  end

  test "destroy follow removes the edge" do
    post base_app_avatar_follow_url(@target_avatar.public_id, ri: "jp", host: @host),
         headers: as_user_headers(@user, host: @host)

    assert_difference("AvatarFollow.count", -1) do
      delete base_app_avatar_follow_url(@target_avatar.public_id, ri: "jp", host: @host),
             headers: as_user_headers(@user, host: @host)
    end

    assert_response :no_content
  end

  test "destroy follow answers not found when no edge exists" do
    delete base_app_avatar_follow_url(@target_avatar.public_id, ri: "jp", host: @host),
           headers: as_user_headers(@user, host: @host)

    assert_response :not_found
  end

  test "create block records the edge from the selected avatar to the target" do
    assert_difference("AvatarBlock.count", 1) do
      post base_app_avatar_block_url(@target_avatar.public_id, ri: "jp", host: @host),
           headers: as_user_headers(@user, host: @host)
    end

    assert_response :created
    assert AvatarBlock.exists?(blocker_avatar: @actor_avatar, blocked_avatar: @target_avatar)
  end

  test "destroy block removes the edge" do
    post base_app_avatar_block_url(@target_avatar.public_id, ri: "jp", host: @host),
         headers: as_user_headers(@user, host: @host)

    assert_difference("AvatarBlock.count", -1) do
      delete base_app_avatar_block_url(@target_avatar.public_id, ri: "jp", host: @host),
             headers: as_user_headers(@user, host: @host)
    end

    assert_response :no_content
  end

  test "create mute records the edge from the selected avatar to the target" do
    assert_difference("AvatarMute.count", 1) do
      post base_app_avatar_mute_url(@target_avatar.public_id, ri: "jp", host: @host),
           headers: as_user_headers(@user, host: @host)
    end

    assert_response :created
    assert AvatarMute.exists?(muter_avatar: @actor_avatar, muted_avatar: @target_avatar)
  end

  test "destroy mute removes the edge" do
    post base_app_avatar_mute_url(@target_avatar.public_id, ri: "jp", host: @host),
         headers: as_user_headers(@user, host: @host)

    assert_difference("AvatarMute.count", -1) do
      delete base_app_avatar_mute_url(@target_avatar.public_id, ri: "jp", host: @host),
             headers: as_user_headers(@user, host: @host)
    end

    assert_response :no_content
  end

  test "create follow answers not found for an unknown target avatar" do
    post base_app_avatar_follow_url("nonexistent-avatar-public-id", ri: "jp", host: @host),
         headers: as_user_headers(@user, host: @host)

    assert_response :not_found
  end
end
