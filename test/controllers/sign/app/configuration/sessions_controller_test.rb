# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Configuration::SessionsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :user_statuses, :user_token_statuses, :user_token_kinds,
           :app_preference_chronicle_levels, :app_preference_chronicle_events

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = users(:one)
    @host = ENV["ID_SERVICE_URL"] || "id.app.localhost"
    @headers = as_user_headers(@user, host: @host)
    @unauthenticated_headers = { "Host" => @host }.freeze
  end

  # ===================================================================
  # index
  # ===================================================================

  test "index returns active sessions as JSON" do
    headers = as_user_headers(@user, host: @host, headers: { "Accept" => "application/json" })
    get sign_app_configuration_sessions_url(ri: "jp", format: :json), headers: headers

    assert_response :success
    assert response.parsed_body.key?("sessions")
  end

  test "index excludes expired sessions from JSON response" do
    expired_token = UserToken.create!(
      user_id: @user.id,
      public_id: "expired_#{SecureRandom.hex(4)}",
      refresh_expires_at: 1.day.from_now,
      user_token_kind_id: UserTokenKind::BROWSER_WEB,
    )
    expired_token.revoke!

    headers = as_user_headers(@user, host: @host, headers: { "Accept" => "application/json" })
    get sign_app_configuration_sessions_url(ri: "jp", format: :json), headers: headers

    assert_response :success
    body = response.parsed_body
    public_ids = body["sessions"].pluck("public_id")

    assert_not_includes public_ids, expired_token.public_id
  end

  test "index excludes rotated and refresh-expired sessions from JSON response" do
    rotated_token = UserToken.create!(user_id: @user.id, user_token_kind_id: UserTokenKind::BROWSER_WEB)
    rotated_refresh = rotated_token.rotate_refresh_token!
    Sign::RefreshTokenService.call(refresh_token: rotated_refresh)

    refresh_expired = UserToken.create!(
      user_id: @user.id,
      refresh_expires_at: 1.minute.ago,
      user_token_kind_id: UserTokenKind::BROWSER_WEB,
    )

    headers = as_user_headers(@user, host: @host, headers: { "Accept" => "application/json" })
    get sign_app_configuration_sessions_url(ri: "jp", format: :json), headers: headers

    assert_response :success
    public_ids = response.parsed_body["sessions"].pluck("public_id")

    assert_not_includes public_ids, rotated_token.reload.public_id
    assert_not_includes public_ids, refresh_expired.public_id
  end

  test "index returns HTML by default" do
    get sign_app_configuration_sessions_url(ri: "jp"), headers: @headers

    assert_response :success
  end

  test "index requires authentication" do
    get sign_app_configuration_sessions_url(ri: "jp"), headers: @unauthenticated_headers

    assert_response :redirect
  end

  # ===================================================================
  # destroy
  # ===================================================================

  test "destroy revokes session and returns see_other" do
    user_token = UserToken.create!(
      user_id: @user.id,
      public_id: "test_session_#{SecureRandom.hex(4)}",
      refresh_expires_at: 1.day.from_now,
      user_token_kind_id: UserTokenKind::BROWSER_WEB,
    )

    delete sign_app_configuration_session_url(user_token.public_id, ri: "jp"), headers: @headers

    assert_response :see_other

    user_token.reload

    assert_not_nil user_token.expired_at
  end

  test "destroy current session returns error redirect instead of revoking" do
    current_session_id = @headers["X-TEST-SESSION-PUBLIC-ID"]
    delete sign_app_configuration_session_url(current_session_id, ri: "jp"), headers: @headers

    assert_response :redirect
    assert_match(/configuration\/sessions/, response.location)

    # Current session must remain alive
    current_token = UserToken.find_by!(public_id: current_session_id)

    assert_nil current_token.expired_at
  end

  test "destroy non-existent session returns 404" do
    delete sign_app_configuration_session_url("nonexistent_public_id", ri: "jp"), headers: @headers

    assert_response :not_found
  end

  test "destroy requires authentication" do
    user_token = UserToken.create!(
      user_id: @user.id,
      public_id: "noauth_#{SecureRandom.hex(4)}",
      refresh_expires_at: 1.day.from_now,
      user_token_kind_id: UserTokenKind::BROWSER_WEB,
    )

    delete sign_app_configuration_session_url(user_token.public_id, ri: "jp"),
           headers: @unauthenticated_headers

    assert_response :redirect
    user_token.reload

    assert_nil user_token.expired_at
  end

  test "destroy does not revoke session belonging to another user" do
    other_user = users(:two)
    other_user_token = UserToken.create!(
      user_id: other_user.id,
      public_id: "other_user_#{SecureRandom.hex(4)}",
      refresh_expires_at: 1.day.from_now,
      user_token_kind_id: UserTokenKind::BROWSER_WEB,
    )

    delete sign_app_configuration_session_url(other_user_token.public_id, ri: "jp"),
           headers: @headers

    # set_session scopes to current_user, so it does not find it and returns 404.
    assert_response :not_found
    other_user_token.reload

    assert_nil other_user_token.expired_at
  end

  # ===================================================================
  # others
  # ===================================================================

  test "others revokes active sessions except current session" do
    current_session_id = @headers["X-TEST-SESSION-PUBLIC-ID"]
    token_one = UserToken.create!(
      user_id: @user.id,
      public_id: "others_one_#{SecureRandom.hex(4)}",
      refresh_expires_at: 1.day.from_now,
      user_token_kind_id: UserTokenKind::BROWSER_WEB,
    )
    token_two = UserToken.create!(
      user_id: @user.id,
      public_id: "others_two_#{SecureRandom.hex(4)}",
      refresh_expires_at: 1.day.from_now,
      user_token_kind_id: UserTokenKind::BROWSER_WEB,
    )

    delete others_sign_app_configuration_sessions_url(ri: "jp"), headers: @headers

    assert_response :see_other
    current_session = UserToken.find_by!(public_id: current_session_id)
    token_one.reload
    token_two.reload

    assert_nil current_session.expired_at
    assert_not_nil token_one.expired_at
    assert_not_nil token_two.expired_at
    assert_not response_has_cookie?(::Authentication::Base::ACCESS_COOKIE_KEY)
    assert_not response_has_cookie?(::Authentication::Base::REFRESH_COOKIE_KEY)
  end

  test "others with no other sessions still succeeds (boundary: 0 other sessions)" do
    # Only the current session exists (created by as_user_headers)
    # Clean up any extra tokens
    current_session_id = @headers["X-TEST-SESSION-PUBLIC-ID"]
    UserToken.where(user_id: @user.id).where.not(public_id: current_session_id).delete_all

    delete others_sign_app_configuration_sessions_url(ri: "jp"), headers: @headers

    assert_response :see_other
    current_session = UserToken.find_by!(public_id: current_session_id)

    assert_nil current_session.expired_at
  end

  test "others requires authentication" do
    delete others_sign_app_configuration_sessions_url(ri: "jp"), headers: @unauthenticated_headers

    assert_response :redirect
  end

  test "others does not revoke already-expired sessions" do
    already_expired = UserToken.create!(
      user_id: @user.id,
      public_id: "already_exp_#{SecureRandom.hex(4)}",
      refresh_expires_at: 1.day.from_now,
      user_token_kind_id: UserTokenKind::BROWSER_WEB,
    )
    already_expired.revoke!
    original_expired_at = already_expired.reload.expired_at

    delete others_sign_app_configuration_sessions_url(ri: "jp"), headers: @headers

    assert_response :see_other
    already_expired.reload

    assert_equal original_expired_at.to_i, already_expired.expired_at.to_i
  end

  # ===================================================================
  # HTML UI elements
  # ===================================================================

  test "index shows revoke all other sessions button" do
    UserToken.create!(
      user_id: @user.id,
      public_id: "others_btn_#{SecureRandom.hex(4)}",
      refresh_expires_at: 1.day.from_now,
      user_token_kind_id: UserTokenKind::BROWSER_WEB,
    )

    get sign_app_configuration_sessions_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_select "form[action^='#{others_sign_app_configuration_sessions_path}']"
    assert_select "button", text: I18n.t("sign.app.configuration.sessions.revoke.others_button")
  end

  test "should show back link on index page" do
    get sign_app_configuration_sessions_url(ri: "jp"), headers: @headers

    assert_response :success
  end

  test "should show up link on index page" do
    get sign_app_configuration_sessions_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_select "a[href=?]", sign_app_configuration_path(ri: "jp")
  end
end
