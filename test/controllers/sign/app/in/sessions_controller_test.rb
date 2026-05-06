# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::In::SessionsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users

  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = users(:one)
    # Clean up any existing tokens for this user
    UserToken.where(user: @user).delete_all
    @original_allow_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = false
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @original_allow_forgery_protection
  end

  # ===================================================================
  # show -- authentication & access control
  # ===================================================================

  test "show without authentication redirects to login" do
    get sign_app_in_session_url(ri: "jp"),
        headers: browser_headers.merge("Host" => @host)

    assert_redirected_to new_sign_app_in_url(ri: "jp")
  end

  test "show with restricted session displays sessions" do
    create_active_session(@user)
    token = create_restricted_session(@user)
    headers = as_user_headers_with_token(@user, token, host: @host)

    get sign_app_in_session_url(ri: "jp"), headers: headers

    assert_response :success
    assert_not response.redirect?
    assert_select "input[type=radio][name=ref]"
    assert_select "input[type=checkbox][name='revoke_refs[]']", false
    assert_select "button", text: /キャンセルしてログアウト/
  end

  test "show counts only usable active sessions" do
    active_token = UserToken.create!(user: @user, status: UserToken::STATUS_ACTIVE)
    rotated_refresh = active_token.rotate_refresh_token!
    Sign::RefreshTokenService.call(refresh_token: rotated_refresh)

    current_active = UserToken.where(user_id: @user.id, status: UserToken::STATUS_ACTIVE).order(:created_at).last
    other_active = UserToken.create!(user: @user, status: UserToken::STATUS_ACTIVE)
    other_active.rotate_refresh_token!
    restricted_token = create_restricted_session(@user)
    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    get sign_app_in_session_url(ri: "jp"), headers: headers

    assert_response :success
    assert_includes response.body, "(2/#{UserToken::MAX_SESSIONS_PER_USER})"
    assert_not_equal active_token.public_id, current_active.public_id
  end

  test "show with active session returns forbidden" do
    active_token = create_active_session(@user)
    headers = as_user_headers_with_token(@user, active_token, host: @host)

    get sign_app_in_session_url(ri: "jp"), headers: headers

    assert_response :forbidden
  end

  # ===================================================================
  # update -- authentication & access control
  # ===================================================================

  test "update without authentication redirects to login" do
    patch sign_app_in_session_url(ri: "jp"),
          params: { revoke_refs: ["some-ref"] },
          headers: browser_headers.merge(
            "Host" => @host,
            "Origin" => "http://#{@host}",
            "HTTP_ORIGIN" => "http://#{@host}",
          )

    assert_redirected_to new_sign_app_in_url(ri: "jp")
  end

  test "update with active session returns forbidden" do
    active_token = create_active_session(@user)
    headers = as_user_headers_with_token(@user, active_token, host: @host)

    patch sign_app_in_session_url(ri: "jp"),
          params: { revoke_refs: ["some-ref"] },
          headers: headers

    assert_response :forbidden
  end

  # ===================================================================
  # update -- empty selections
  # ===================================================================

  test "update without selections flashes alert and re-renders show" do
    token = create_restricted_session(@user)
    headers = as_user_headers_with_token(@user, token, host: @host)

    patch sign_app_in_session_url(ri: "jp"),
          params: { revoke_refs: [] },
          headers: headers

    assert_response :unprocessable_content
  end

  # ===================================================================
  # update -- revoke by refs (batch) + promotion
  # ===================================================================

  test "update revokes selected sessions and promotes restricted session" do
    active_token1 = UserToken.create!(user: @user, status: UserToken::STATUS_ACTIVE)
    active_token1.rotate_refresh_token!

    active_token2 = UserToken.create!(user: @user, status: UserToken::STATUS_ACTIVE)
    active_token2.rotate_refresh_token!

    restricted_token = UserToken.create!(user: @user, status: UserToken::STATUS_RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    patch sign_app_in_session_url(ri: "jp"),
          params: { revoke_refs: [active_token1.signed_ref] },
          headers: headers

    restricted_token.reload

    assert_equal UserToken::STATUS_ACTIVE, restricted_token.status

    active_token1.reload

    assert_not_nil active_token1.expired_at

    # Unrevoked active session remains
    active_token2.reload

    assert_nil active_token2.expired_at
  end

  test "update revokes session but does not promote when still at limit" do
    active_token1 = UserToken.create!(user: @user, status: UserToken::STATUS_ACTIVE)
    active_token1.rotate_refresh_token!

    active_token2 = UserToken.create!(user: @user, status: UserToken::STATUS_ACTIVE)
    active_token2.rotate_refresh_token!

    restricted_token = UserToken.create!(user: @user, status: UserToken::STATUS_RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    # Send an invalid ref so nothing actually gets revoked
    patch sign_app_in_session_url(ri: "jp"),
          params: { revoke_refs: ["invalid_ref_value"] },
          headers: headers

    # Still restricted -- not promoted because active_count == MAX_SESSIONS_PER_USER
    restricted_token.reload

    assert_equal UserToken::STATUS_RESTRICTED, restricted_token.status
    assert_response :success # re-renders show
  end

  test "update skips current session ref in batch revoke" do
    # Need 2 active sessions to prevent auto-promotion after no-op revoke
    active_token1 = UserToken.create!(user: @user, status: UserToken::STATUS_ACTIVE)
    active_token1.rotate_refresh_token!

    active_token2 = UserToken.create!(user: @user, status: UserToken::STATUS_ACTIVE)
    active_token2.rotate_refresh_token!

    restricted_token = UserToken.create!(user: @user, status: UserToken::STATUS_RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    patch sign_app_in_session_url(ri: "jp"),
          params: { revoke_refs: [restricted_token.signed_ref] },
          headers: headers

    restricted_token.reload

    assert_equal UserToken::STATUS_RESTRICTED, restricted_token.status
    assert_nil restricted_token.revoked_at
  end

  test "update ignores ref belonging to another user" do
    other_user = users(:two)
    UserToken.where(user: other_user).delete_all
    other_token = UserToken.create!(user: other_user, status: UserToken::STATUS_ACTIVE)
    other_token.rotate_refresh_token!

    restricted_token = create_restricted_session(@user)
    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    patch sign_app_in_session_url(ri: "jp"),
          params: { revoke_refs: [other_token.signed_ref] },
          headers: headers

    other_token.reload

    assert_nil other_token.expired_at
    assert_nil other_token.revoked_at
  end

  # ===================================================================
  # update -- revoke by single ref param
  # ===================================================================

  test "update with ref param revokes specific session" do
    active_token = UserToken.create!(user: @user, status: UserToken::STATUS_ACTIVE)
    active_token.rotate_refresh_token!

    restricted_token = UserToken.create!(user: @user, status: UserToken::STATUS_RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    patch sign_app_in_session_url(ri: "jp"),
          params: { ref: active_token.signed_ref },
          headers: headers

    active_token.reload

    assert_not_nil active_token.expired_at

    restricted_token.reload

    assert_equal UserToken::STATUS_ACTIVE, restricted_token.status
  end

  test "update with ref param rejects revoking current session" do
    # Need 2 active sessions to prevent auto-promotion
    active_token1 = UserToken.create!(user: @user, status: UserToken::STATUS_ACTIVE)
    active_token1.rotate_refresh_token!

    active_token2 = UserToken.create!(user: @user, status: UserToken::STATUS_ACTIVE)
    active_token2.rotate_refresh_token!

    restricted_token = UserToken.create!(user: @user, status: UserToken::STATUS_RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    patch sign_app_in_session_url(ri: "jp"),
          params: { ref: restricted_token.signed_ref },
          headers: headers

    restricted_token.reload

    assert_equal UserToken::STATUS_RESTRICTED, restricted_token.status
    assert_nil restricted_token.revoked_at
  end

  test "update with invalid ref param flashes alert and stays on page" do
    # Need 2 active sessions to prevent auto-promotion
    active_token1 = UserToken.create!(user: @user, status: UserToken::STATUS_ACTIVE)
    active_token1.rotate_refresh_token!

    active_token2 = UserToken.create!(user: @user, status: UserToken::STATUS_ACTIVE)
    active_token2.rotate_refresh_token!

    restricted_token = UserToken.create!(user: @user, status: UserToken::STATUS_RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    patch sign_app_in_session_url(ri: "jp"),
          params: { ref: "totally_invalid_ref" },
          headers: headers

    assert_response :success # re-renders show
    restricted_token.reload

    assert_equal UserToken::STATUS_RESTRICTED, restricted_token.status
  end

  # ===================================================================
  # update -- redirect after promotion
  # ===================================================================

  test "update promotes and redirects to configuration path by default" do
    active_token = UserToken.create!(user: @user, status: UserToken::STATUS_ACTIVE)
    active_token.rotate_refresh_token!

    restricted_token = UserToken.create!(user: @user, status: UserToken::STATUS_RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    patch sign_app_in_session_url(ri: "jp"),
          params: { revoke_refs: [active_token.signed_ref] },
          headers: headers

    assert_response :redirect
    assert_match %r{/configuration}, response.location
  end

  test "update with rd param decodes Base64 and redirects to decoded path" do
    active_token = UserToken.create!(user: @user, status: UserToken::STATUS_ACTIVE)
    active_token.rotate_refresh_token!

    restricted_token = UserToken.create!(user: @user, status: UserToken::STATUS_RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    encoded_rd = Base64.urlsafe_encode64("/configuration")

    patch sign_app_in_session_url(ri: "jp", rd: encoded_rd),
          params: { revoke_refs: [active_token.signed_ref] },
          headers: headers

    restricted_token.reload

    assert_equal UserToken::STATUS_ACTIVE, restricted_token.status

    assert_response :redirect
    assert_match %r{/configuration}, response.location
    assert_no_match encoded_rd, response.location
  end

  test "update with invalid rd param falls back to default path" do
    active_token = UserToken.create!(user: @user, status: UserToken::STATUS_ACTIVE)
    active_token.rotate_refresh_token!

    restricted_token = UserToken.create!(user: @user, status: UserToken::STATUS_RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    patch sign_app_in_session_url(ri: "jp", rd: "!!!invalid-base64!!!"),
          params: { revoke_refs: [active_token.signed_ref] },
          headers: headers

    restricted_token.reload

    assert_equal UserToken::STATUS_ACTIVE, restricted_token.status

    assert_response :redirect
    assert_match %r{/configuration}, response.location
  end

  # ===================================================================
  # destroy -- authentication & access control
  # ===================================================================

  test "destroy without authentication redirects to login" do
    delete sign_app_in_session_url(ri: "jp"),
           headers: browser_headers.merge(
             "Host" => @host,
             "Origin" => "http://#{@host}",
             "HTTP_ORIGIN" => "http://#{@host}",
           )

    assert_redirected_to new_sign_app_in_url(ri: "jp")
  end

  test "destroy with active session returns forbidden" do
    active_token = create_active_session(@user)
    headers = as_user_headers_with_token(@user, active_token, host: @host)

    delete sign_app_in_session_url(ri: "jp"), headers: headers

    assert_response :forbidden
  end

  # ===================================================================
  # destroy -- cancel restricted session (no ref)
  # ===================================================================

  test "destroy cancels restricted session and redirects to login" do
    token = create_restricted_session(@user)
    headers = as_user_headers_with_token(@user, token, host: @host)

    delete sign_app_in_session_url(ri: "jp"), headers: headers

    assert_redirected_to new_sign_app_in_url(ri: "jp")

    token.reload

    assert_not_nil token.expired_at
    assert_equal UserToken::STATUS_REVOKED, token.status
  end

  # ===================================================================
  # destroy -- revoke specific session (with ref)
  # ===================================================================

  test "destroy with ref param revokes specific session and re-renders show" do
    active_token = UserToken.create!(user: @user, status: UserToken::STATUS_ACTIVE)
    active_token.rotate_refresh_token!

    restricted_token = UserToken.create!(user: @user, status: UserToken::STATUS_RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    delete sign_app_in_session_url(ri: "jp"),
           params: { ref: active_token.signed_ref },
           headers: headers

    assert_response :success # re-renders show, does not redirect

    active_token.reload

    assert_not_nil active_token.expired_at

    restricted_token.reload

    assert_equal UserToken::STATUS_RESTRICTED, restricted_token.status
  end

  test "destroy with ref param rejects revoking current session" do
    restricted_token = create_restricted_session(@user)
    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    delete sign_app_in_session_url(ri: "jp"),
           params: { ref: restricted_token.signed_ref },
           headers: headers

    assert_response :success
    restricted_token.reload

    assert_equal UserToken::STATUS_RESTRICTED, restricted_token.status
    assert_nil restricted_token.revoked_at
  end

  test "destroy with invalid ref param does not revoke anything" do
    restricted_token = create_restricted_session(@user)
    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    delete sign_app_in_session_url(ri: "jp"),
           params: { ref: "invalid_ref" },
           headers: headers

    assert_response :success
    restricted_token.reload

    assert_equal UserToken::STATUS_RESTRICTED, restricted_token.status
  end

  test "destroy with ref belonging to another user does not revoke" do
    other_user = users(:two)
    UserToken.where(user: other_user).delete_all
    other_token = UserToken.create!(user: other_user, status: UserToken::STATUS_ACTIVE)
    other_token.rotate_refresh_token!

    restricted_token = create_restricted_session(@user)
    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    delete sign_app_in_session_url(ri: "jp"),
           params: { ref: other_token.signed_ref },
           headers: headers

    other_token.reload

    assert_nil other_token.expired_at
  end

  # ===================================================================
  # restricted session expiry (boundary analysis)
  # ===================================================================

  test "restricted session at 14 minutes is still accessible (boundary: within TTL)" do
    token = create_restricted_session(@user, expires_at: 15.minutes.from_now)
    headers = as_user_headers_with_token(@user, token, host: @host)

    travel 14.minutes do
      get sign_app_in_session_url(ri: "jp"), headers: headers
    end

    assert_response :success
    token.reload

    assert_equal UserToken::STATUS_RESTRICTED, token.status
  end

  test "restricted session expires after 15 minutes and is locked on in/session" do
    token = create_restricted_session(@user, expires_at: 15.minutes.from_now)
    headers = as_user_headers_with_token(@user, token, host: @host)
    events = []

    travel 16.minutes do
      Rails.event.stub(
        :notify, lambda { |*args|
                   events << [args.first, args.last.is_a?(Hash) ? args.last : {}]
                 },
      ) do
        get sign_app_in_session_url(ri: "jp"), headers: headers
      end
    end

    assert_response :locked
    assert_equal "きんそくじこうです", response.body
    assert_not response.redirect?
    assert_includes events.map(&:first), "session.restricted.expired"
  end

  # ===================================================================
  # RestrictedSessionGuard -- non-session routes blocked
  # ===================================================================

  test "restricted session is blocked on non-session app routes" do
    token = create_restricted_session(@user)
    headers = as_user_headers_with_token(@user, token, host: @host)

    # Try to access configuration page (not /in/sessions)
    get sign_app_configuration_url(ri: "jp"), headers: headers

    assert_response :locked
    assert_equal "きんそくじこうです", response.body
  end

  private

  def create_restricted_session(user, expires_at: nil)
    token = UserToken.create!(
      user: user,
      status: UserToken::STATUS_RESTRICTED,
      user_token_status_id: UserTokenStatus::NOTHING,
      user_token_kind_id: UserTokenKind::BROWSER_WEB,
    )
    token.rotate_refresh_token!(expires_at: expires_at)
    token
  end

  def create_active_session(user)
    token = UserToken.create!(
      user: user,
      status: UserToken::STATUS_ACTIVE,
      user_token_status_id: UserTokenStatus::NOTHING,
      user_token_kind_id: UserTokenKind::BROWSER_WEB,
    )
    token.rotate_refresh_token!
    token
  end

  def as_user_headers_with_token(user, token, host:)
    access_token = Authentication::Base::Token.encode(user, host: host, session_public_id: token.public_id)
    browser_headers.merge(
      "Host" => host,
      "Origin" => "http://#{host}",
      "HTTP_ORIGIN" => "http://#{host}",
      "Authorization" => "Bearer #{access_token}",
      "Cookie" => [
        "csrf_token=test_csrf_token",
        "#{Authentication::Base::ACCESS_COOKIE_KEY}=#{access_token}",
      ].join("; "),
    )
  end
end
