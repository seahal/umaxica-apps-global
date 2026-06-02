# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::In::SessionsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients

  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = clients(:one)
    # Clean up any existing tokens for this user
    ClientToken.where(user: @user).delete_all
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

    assert_response :redirect

    assert_redirected_to new_sign_app_sign_in_url(ri: "jp")
  end

  test "show without authentication redirects to public sign host and preserves absolute return target" do
    with_env(
      "ID_SERVICE_URL" => "id.app.localhost",
      "SIGN_SERVICE_URL" => "id.umaxica.app",
    ) do
      Rails.application.reload_routes!

      get(
        "https://id.umaxica.app/settings/sessions?ri=jp",
        headers: browser_headers.merge("Host" => "id.umaxica.app"),
      )

      assert_response :redirect
      location = URI.parse(jump_rt_url_from_location(response.location))
      params = Rack::Utils.parse_query(location.query)

      assert_equal "https", location.scheme
      assert_equal "id.umaxica.app", location.host
      assert_equal "/sign/in/new", location.path
      assert_equal "jp", params["ri"]
      assert_not params.key?("pt")
    end
  ensure
    Rails.application.reload_routes!
  end

  test "show with restricted session displays sessions" do
    create_active_session(@user)
    token = create_restricted_session(@user)
    headers = as_user_headers_with_token(@user, token, host: @host)

    get sign_app_in_session_url(ri: "jp"), headers: headers

    assert_response :success
    assert_not response.redirect?
    assert_select "form[data-turbo=false][action=?]", sign_app_in_session_path(ri: "jp")
    assert_select "input[type=radio][name=ref]"
    assert_select "input[type=checkbox][name='revoke_refs[]']", false
    assert_select "form[data-turbo=false] button", text: /キャンセルしてログアウト/
  end

  test "show counts only usable active sessions" do
    active_token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    rotated_refresh = active_token.rotate_refresh_token!
    Sign::RefreshTokenService.call(refresh_token: rotated_refresh)

    current_active = ClientToken.where(user_id: @user.id, user_token_status_id: ClientTokenStatus::ACTIVE).order(:created_at).last
    other_active = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    other_active.rotate_refresh_token!
    restricted_token = create_restricted_session(@user)
    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    get sign_app_in_session_url(ri: "jp"), headers: headers

    assert_response :success
    assert_includes response.body, "(2/#{ClientToken::MAX_SESSIONS_PER_USER})"
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

    assert_redirected_to new_sign_app_sign_in_url(ri: "jp")
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
    active_token1 = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    active_token1.rotate_refresh_token!

    active_token2 = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    active_token2.rotate_refresh_token!

    restricted_token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    patch sign_app_in_session_url(ri: "jp"),
          params: { revoke_refs: [active_token1.signed_ref] },
          headers: headers

    restricted_token.reload

    assert_equal ClientTokenStatus::ACTIVE, restricted_token.user_token_status_id

    active_token1.reload

    assert_not active_token1.currently_usable?

    # Unrevoked active session remains
    active_token2.reload

    assert_predicate active_token2, :currently_usable?
  end

  test "update revokes session but does not promote when still at limit" do
    active_token1 = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    active_token1.rotate_refresh_token!

    active_token2 = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    active_token2.rotate_refresh_token!

    restricted_token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    # Send an invalid ref so nothing actually gets revoked
    patch sign_app_in_session_url(ri: "jp"),
          params: { revoke_refs: ["invalid_ref_value"] },
          headers: headers

    # Still restricted -- not promoted because active_count == MAX_SESSIONS_PER_USER
    restricted_token.reload

    assert_equal ClientTokenStatus::RESTRICTED, restricted_token.user_token_status_id
    assert_response :success # re-renders show
  end

  test "update skips current session ref in batch revoke" do
    # Need 2 active sessions to prevent auto-promotion after no-op revoke
    active_token1 = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    active_token1.rotate_refresh_token!

    active_token2 = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    active_token2.rotate_refresh_token!

    restricted_token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    patch sign_app_in_session_url(ri: "jp"),
          params: { revoke_refs: [restricted_token.signed_ref] },
          headers: headers

    restricted_token.reload

    assert_equal ClientTokenStatus::RESTRICTED, restricted_token.user_token_status_id
    assert_predicate restricted_token, :currently_usable?
  end

  test "update ignores ref belonging to another user" do
    other_user = clients(:two)
    ClientToken.where(user: other_user).delete_all
    other_token = ClientToken.create!(user: other_user, user_token_status_id: ClientTokenStatus::ACTIVE)
    other_token.rotate_refresh_token!

    restricted_token = create_restricted_session(@user)
    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    patch sign_app_in_session_url(ri: "jp"),
          params: { revoke_refs: [other_token.signed_ref] },
          headers: headers

    other_token.reload

    assert_predicate other_token, :currently_usable?
  end

  # ===================================================================
  # update -- revoke by single ref param
  # ===================================================================

  test "update with ref param revokes specific session" do
    active_token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    active_token.rotate_refresh_token!

    restricted_token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    patch sign_app_in_session_url(ri: "jp"),
          params: { ref: active_token.signed_ref },
          headers: headers

    active_token.reload

    assert_not active_token.currently_usable?

    restricted_token.reload

    assert_equal ClientTokenStatus::ACTIVE, restricted_token.user_token_status_id
  end

  test "update with ref param rejects revoking current session" do
    # Need 2 active sessions to prevent auto-promotion
    active_token1 = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    active_token1.rotate_refresh_token!

    active_token2 = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    active_token2.rotate_refresh_token!

    restricted_token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    patch sign_app_in_session_url(ri: "jp"),
          params: { ref: restricted_token.signed_ref },
          headers: headers

    restricted_token.reload

    assert_equal ClientTokenStatus::RESTRICTED, restricted_token.user_token_status_id
    assert_predicate restricted_token, :currently_usable?
  end

  test "update with invalid ref param flashes alert and stays on page" do
    # Need 2 active sessions to prevent auto-promotion
    active_token1 = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    active_token1.rotate_refresh_token!

    active_token2 = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    active_token2.rotate_refresh_token!

    restricted_token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    patch sign_app_in_session_url(ri: "jp"),
          params: { ref: "totally_invalid_ref" },
          headers: headers

    assert_response :success # re-renders show
    restricted_token.reload

    assert_equal ClientTokenStatus::RESTRICTED, restricted_token.user_token_status_id
  end

  # ===================================================================
  # update -- redirect after promotion
  # ===================================================================

  test "update promotes and redirects to settings path by default" do
    active_token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    active_token.rotate_refresh_token!

    restricted_token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    patch sign_app_in_session_url(ri: "jp"),
          params: { revoke_refs: [active_token.signed_ref] },
          headers: headers

    assert_response :redirect
    assert_match %r{/settings}, response.location
  end

  test "update with pt param redirects to the requested path" do
    active_token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    active_token.rotate_refresh_token!

    restricted_token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    pt = "/settings"

    patch sign_app_in_session_url(ri: "jp", pt: pt),
          params: { revoke_refs: [active_token.signed_ref] },
          headers: headers

    restricted_token.reload

    assert_equal ClientTokenStatus::ACTIVE, restricted_token.user_token_status_id

    assert_response :redirect
    assert_match %r{/settings}, response.location
  end

  test "update with invalid pt param falls back to default path" do
    active_token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    active_token.rotate_refresh_token!

    restricted_token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    patch sign_app_in_session_url(ri: "jp", pt: "not-a-token"),
          params: { revoke_refs: [active_token.signed_ref] },
          headers: headers

    restricted_token.reload

    assert_equal ClientTokenStatus::ACTIVE, restricted_token.user_token_status_id

    assert_response :redirect
    assert_match %r{/settings}, response.location
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

    assert_redirected_to new_sign_app_sign_in_url(ri: "jp")
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

    assert_redirected_to new_sign_app_sign_in_url(ri: "jp")

    token.reload

    assert_not token.currently_usable?
    assert_equal ClientTokenStatus::REVOKED, token.user_token_status_id
  end

  # ===================================================================
  # destroy -- revoke specific session (with ref)
  # ===================================================================

  test "destroy with ref param revokes specific session and re-renders show" do
    active_token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::ACTIVE)
    active_token.rotate_refresh_token!

    restricted_token = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    delete sign_app_in_session_url(ri: "jp"),
           params: { ref: active_token.signed_ref },
           headers: headers

    assert_response :success # re-renders show, does not redirect

    active_token.reload

    assert_not active_token.currently_usable?

    restricted_token.reload

    assert_equal ClientTokenStatus::RESTRICTED, restricted_token.user_token_status_id
  end

  test "destroy with ref param rejects revoking current session" do
    restricted_token = create_restricted_session(@user)
    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    delete sign_app_in_session_url(ri: "jp"),
           params: { ref: restricted_token.signed_ref },
           headers: headers

    assert_response :success
    restricted_token.reload

    assert_equal ClientTokenStatus::RESTRICTED, restricted_token.user_token_status_id
    assert_predicate restricted_token, :currently_usable?
  end

  test "destroy with invalid ref param does not revoke anything" do
    restricted_token = create_restricted_session(@user)
    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    delete sign_app_in_session_url(ri: "jp"),
           params: { ref: "invalid_ref" },
           headers: headers

    assert_response :success
    restricted_token.reload

    assert_equal ClientTokenStatus::RESTRICTED, restricted_token.user_token_status_id
  end

  test "destroy with ref belonging to another user does not revoke" do
    other_user = clients(:two)
    ClientToken.where(user: other_user).delete_all
    other_token = ClientToken.create!(user: other_user, user_token_status_id: ClientTokenStatus::ACTIVE)
    other_token.rotate_refresh_token!

    restricted_token = create_restricted_session(@user)
    headers = as_user_headers_with_token(@user, restricted_token, host: @host)

    delete sign_app_in_session_url(ri: "jp"),
           params: { ref: other_token.signed_ref },
           headers: headers

    other_token.reload

    assert_predicate other_token, :currently_usable?
  end

  # ===================================================================
  # restricted session expiry (boundary analysis)
  # ===================================================================

  test "restricted session at 14 minutes is still accessible (boundary: within TTL)" do
    token = create_restricted_session(@user, discarded_at: 15.minutes.from_now)
    headers = as_user_headers_with_token(@user, token, host: @host)

    travel 14.minutes do
      get sign_app_in_session_url(ri: "jp"), headers: headers

      assert_response :success
    end

    assert_response :success
    token.reload

    assert_equal ClientTokenStatus::RESTRICTED, token.user_token_status_id
  end

  test "restricted session expires after 15 minutes and is locked on in/session" do
    token = create_restricted_session(@user, discarded_at: 15.minutes.from_now)
    headers = as_user_headers_with_token(@user, token, host: @host)
    logs = []

    travel 16.minutes do
      Rails.logger.stub(
        :info, ->(*args) do
                 message = args.first
                 logs << JSON.parse(message, symbolize_names: true) if message.present?
               end,
      ) do
        get sign_app_in_session_url(ri: "jp"), headers: headers
      end
    end

    assert_response :locked
    assert_equal "きんそくじこうです", response.body
    assert_not response.redirect?
    assert_includes logs.pluck(:event), "session.restricted.expired"
  end

  # ===================================================================
  # RestrictedSessionGuard -- non-session routes blocked
  # ===================================================================

  test "restricted session is blocked on non-session app routes" do
    token = create_restricted_session(@user)
    headers = as_user_headers_with_token(@user, token, host: @host)

    # Try to access settings page (not /in/sessions)
    get sign_app_settings_url(ri: "jp"), headers: headers

    assert_response :locked
    assert_equal "きんそくじこうです", response.body
  end

  private

  def create_restricted_session(user, discarded_at: nil)
    token = ClientToken.create!(
      user: user,
      user_token_status_id: ClientTokenStatus::RESTRICTED,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
    )
    token.rotate_refresh_token!(discarded_at: discarded_at)
    token
  end

  def create_active_session(user)
    token = ClientToken.create!(
      user: user,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
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

  def with_env(vars)
    original = {}
    vars.each_key { |key| original[key] = ENV[key] }

    vars.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end

    yield
  ensure
    original.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
