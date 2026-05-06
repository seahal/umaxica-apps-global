# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::In::SessionsControllerTest < ActionDispatch::IntegrationTest
  fixtures :staffs, :staff_statuses, :staff_token_statuses, :staff_token_kinds

  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    host! @host
    @staff = staffs(:one)
    # Clean up any existing tokens for this staff
    StaffToken.where(staff: @staff).delete_all
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
    get sign_org_in_session_url(ri: "jp"),
        headers: browser_headers.merge("Host" => @host)

    assert_response :redirect
    assert_match %r{/in/new}, response.location
  end

  test "show with restricted session displays sessions" do
    active_token = create_active_session(@staff)
    token = create_restricted_session(@staff)
    headers = as_staff_headers_with_token(@staff, token, host: @host)

    get sign_org_in_session_url(ri: "jp"), headers: headers

    assert_response :success
    assert_not response.redirect?
    assert_select "input[type=radio][name=ref]"
    assert_select "input[type=checkbox][name='revoke_session_ids[]']", false
    assert_select "button", text: /キャンセルしてログアウト/
    assert_select "input[type=radio][value=?]", active_token.id.to_s
  end

  test "show with active session returns forbidden" do
    active_token = create_active_session(@staff)
    headers = as_staff_headers_with_token(@staff, active_token, host: @host)

    get sign_org_in_session_url(ri: "jp"), headers: headers

    assert_response :forbidden
  end

  # ===================================================================
  # update -- authentication & access control
  # ===================================================================

  test "update without authentication redirects to login" do
    patch sign_org_in_session_url(ri: "jp"),
          params: { revoke_refs: ["some-ref"] },
          headers: browser_headers.merge(
            "Host" => @host,
            "Origin" => "http://#{@host}",
            "HTTP_ORIGIN" => "http://#{@host}",
          )

    assert_response :redirect
    assert_match %r{/in/new}, response.location
  end

  test "update with active session returns forbidden" do
    active_token = create_active_session(@staff)
    headers = as_staff_headers_with_token(@staff, active_token, host: @host)

    patch sign_org_in_session_url(ri: "jp"),
          params: { revoke_refs: ["some-ref"] },
          headers: headers

    assert_response :forbidden
  end

  # ===================================================================
  # update -- empty selections
  # ===================================================================

  test "update without selections flashes alert and re-renders show" do
    token = create_restricted_session(@staff)
    headers = as_staff_headers_with_token(@staff, token, host: @host)

    patch sign_org_in_session_url(ri: "jp"),
          params: { revoke_refs: [] },
          headers: headers

    assert_response :unprocessable_content
  end

  # ===================================================================
  # update -- revoke by refs (batch) + promotion
  # ===================================================================

  test "update revokes selected sessions and promotes restricted session" do
    active_token1 = StaffToken.create!(staff: @staff, status: StaffToken::STATUS_ACTIVE)
    active_token1.rotate_refresh_token!

    restricted_token = StaffToken.create!(staff: @staff, status: StaffToken::STATUS_RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_staff_headers_with_token(@staff, restricted_token, host: @host)

    patch sign_org_in_session_url(ri: "jp"),
          params: { revoke_refs: [active_token1.signed_ref] },
          headers: headers

    restricted_token.reload

    assert_equal StaffToken::STATUS_ACTIVE, restricted_token.status

    active_token1.reload

    assert_not_nil active_token1.expired_at
  end

  test "update revokes session but does not promote when still at limit" do
    # Create 1 active session -- revoking 0 keeps at limit
    active_token1 = StaffToken.create!(staff: @staff, status: StaffToken::STATUS_ACTIVE)
    active_token1.rotate_refresh_token!

    restricted_token = StaffToken.create!(staff: @staff, status: StaffToken::STATUS_RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_staff_headers_with_token(@staff, restricted_token, host: @host)

    # Send an invalid ref so nothing actually gets revoked
    patch sign_org_in_session_url(ri: "jp"),
          params: { revoke_refs: ["invalid_ref_value"] },
          headers: headers

    # Still restricted -- not promoted because active_count == MAX_SESSIONS_PER_STAFF
    restricted_token.reload

    assert_equal StaffToken::STATUS_RESTRICTED, restricted_token.status
    assert_response :success # re-renders show
  end

  test "update skips current session ref in batch revoke" do
    # Need 1 active session to prevent auto-promotion after no-op revoke
    active_token1 = StaffToken.create!(staff: @staff, status: StaffToken::STATUS_ACTIVE)
    active_token1.rotate_refresh_token!

    restricted_token = StaffToken.create!(staff: @staff, status: StaffToken::STATUS_RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_staff_headers_with_token(@staff, restricted_token, host: @host)

    # Try to revoke the current (restricted) session via refs -- should be skipped
    patch sign_org_in_session_url(ri: "jp"),
          params: { revoke_refs: [restricted_token.signed_ref] },
          headers: headers

    restricted_token.reload
    # Current session should NOT be revoked via batch refs
    assert_equal StaffToken::STATUS_RESTRICTED, restricted_token.status
    assert_nil restricted_token.revoked_at
  end

  test "update ignores ref belonging to another staff" do
    other_staff = staffs(:two)
    StaffToken.where(staff: other_staff).delete_all
    other_token = StaffToken.create!(staff: other_staff, status: StaffToken::STATUS_ACTIVE)
    other_token.rotate_refresh_token!

    restricted_token = create_restricted_session(@staff)
    headers = as_staff_headers_with_token(@staff, restricted_token, host: @host)

    patch sign_org_in_session_url(ri: "jp"),
          params: { revoke_refs: [other_token.signed_ref] },
          headers: headers

    # Other staff's token must remain untouched
    other_token.reload

    assert_nil other_token.expired_at
    assert_nil other_token.revoked_at
  end

  # ===================================================================
  # update -- revoke by single ref param
  # ===================================================================

  test "update with ref param revokes specific session" do
    active_token = StaffToken.create!(staff: @staff, status: StaffToken::STATUS_ACTIVE)
    active_token.rotate_refresh_token!

    restricted_token = StaffToken.create!(staff: @staff, status: StaffToken::STATUS_RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_staff_headers_with_token(@staff, restricted_token, host: @host)

    patch sign_org_in_session_url(ri: "jp"),
          params: { ref: active_token.signed_ref },
          headers: headers

    active_token.reload

    assert_not_nil active_token.expired_at

    # With only 1 active left (now 0 after revoke), restricted should be promoted
    restricted_token.reload

    assert_equal StaffToken::STATUS_ACTIVE, restricted_token.status
  end

  test "update with ref param rejects revoking current session" do
    # Need 1 active session to prevent auto-promotion
    active_token1 = StaffToken.create!(staff: @staff, status: StaffToken::STATUS_ACTIVE)
    active_token1.rotate_refresh_token!

    restricted_token = StaffToken.create!(staff: @staff, status: StaffToken::STATUS_RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_staff_headers_with_token(@staff, restricted_token, host: @host)

    patch sign_org_in_session_url(ri: "jp"),
          params: { ref: restricted_token.signed_ref },
          headers: headers

    restricted_token.reload

    assert_equal StaffToken::STATUS_RESTRICTED, restricted_token.status
    assert_nil restricted_token.revoked_at
  end

  test "update with invalid ref param flashes alert and stays on page" do
    # Need 1 active session to prevent auto-promotion
    active_token1 = StaffToken.create!(staff: @staff, status: StaffToken::STATUS_ACTIVE)
    active_token1.rotate_refresh_token!

    restricted_token = StaffToken.create!(staff: @staff, status: StaffToken::STATUS_RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_staff_headers_with_token(@staff, restricted_token, host: @host)

    patch sign_org_in_session_url(ri: "jp"),
          params: { ref: "totally_invalid_ref" },
          headers: headers

    assert_response :success # re-renders show
    restricted_token.reload

    assert_equal StaffToken::STATUS_RESTRICTED, restricted_token.status
  end

  # ===================================================================
  # update -- redirect after promotion
  # ===================================================================

  test "update promotes and redirects to configuration path by default" do
    active_token = StaffToken.create!(staff: @staff, status: StaffToken::STATUS_ACTIVE)
    active_token.rotate_refresh_token!

    restricted_token = StaffToken.create!(staff: @staff, status: StaffToken::STATUS_RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_staff_headers_with_token(@staff, restricted_token, host: @host)

    patch sign_org_in_session_url(ri: "jp"),
          params: { revoke_refs: [active_token.signed_ref] },
          headers: headers

    assert_response :redirect
    assert_match %r{/configuration}, response.location
  end

  test "update with rd param decodes Base64 and redirects to decoded path" do
    active_token = StaffToken.create!(staff: @staff, status: StaffToken::STATUS_ACTIVE)
    active_token.rotate_refresh_token!

    restricted_token = StaffToken.create!(staff: @staff, status: StaffToken::STATUS_RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_staff_headers_with_token(@staff, restricted_token, host: @host)
    encoded_rd = Base64.urlsafe_encode64("/configuration")

    patch sign_org_in_session_url(ri: "jp", rd: encoded_rd),
          params: { revoke_refs: [active_token.signed_ref] },
          headers: headers

    restricted_token.reload

    assert_equal StaffToken::STATUS_ACTIVE, restricted_token.status
    assert_response :redirect
    assert_match %r{/configuration}, response.location
  end

  test "update with invalid rd param falls back to default path" do
    active_token = StaffToken.create!(staff: @staff, status: StaffToken::STATUS_ACTIVE)
    active_token.rotate_refresh_token!

    restricted_token = StaffToken.create!(staff: @staff, status: StaffToken::STATUS_RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_staff_headers_with_token(@staff, restricted_token, host: @host)

    patch sign_org_in_session_url(ri: "jp", rd: "!!!invalid-base64!!!"),
          params: { revoke_refs: [active_token.signed_ref] },
          headers: headers

    restricted_token.reload

    assert_equal StaffToken::STATUS_ACTIVE, restricted_token.status
    assert_response :redirect
    assert_match %r{/configuration}, response.location
  end

  # ===================================================================
  # destroy -- authentication & access control
  # ===================================================================

  test "destroy without authentication redirects to login" do
    delete sign_org_in_session_url(ri: "jp"),
           headers: browser_headers.merge(
             "Host" => @host,
             "Origin" => "http://#{@host}",
             "HTTP_ORIGIN" => "http://#{@host}",
           )

    assert_response :redirect
    assert_match %r{/in/new}, response.location
  end

  test "destroy with active session returns forbidden" do
    active_token = create_active_session(@staff)
    headers = as_staff_headers_with_token(@staff, active_token, host: @host)

    delete sign_org_in_session_url(ri: "jp"), headers: headers

    assert_response :forbidden
  end

  # ===================================================================
  # destroy -- cancel restricted session (no ref)
  # ===================================================================

  test "destroy cancels restricted session and redirects to login" do
    token = create_restricted_session(@staff)
    headers = as_staff_headers_with_token(@staff, token, host: @host)

    delete sign_org_in_session_url(ri: "jp"), headers: headers

    assert_response :redirect
    assert_match %r{/in/new}, response.location

    token.reload

    assert_not_nil token.expired_at
    assert_equal StaffToken::STATUS_REVOKED, token.status
  end

  # ===================================================================
  # destroy -- revoke specific session (with ref)
  # ===================================================================

  test "destroy with ref param revokes specific session and re-renders show" do
    active_token = StaffToken.create!(staff: @staff, status: StaffToken::STATUS_ACTIVE)
    active_token.rotate_refresh_token!

    restricted_token = StaffToken.create!(staff: @staff, status: StaffToken::STATUS_RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_staff_headers_with_token(@staff, restricted_token, host: @host)

    delete sign_org_in_session_url(ri: "jp"),
           params: { ref: active_token.signed_ref },
           headers: headers

    assert_response :success # re-renders show, does not redirect

    active_token.reload

    assert_not_nil active_token.expired_at

    # Restricted session remains (not cancelled)
    restricted_token.reload

    assert_equal StaffToken::STATUS_RESTRICTED, restricted_token.status
  end

  test "destroy with ref param rejects revoking current session" do
    restricted_token = create_restricted_session(@staff)
    headers = as_staff_headers_with_token(@staff, restricted_token, host: @host)

    delete sign_org_in_session_url(ri: "jp"),
           params: { ref: restricted_token.signed_ref },
           headers: headers

    assert_response :success # re-renders show
    restricted_token.reload

    assert_equal StaffToken::STATUS_RESTRICTED, restricted_token.status
    assert_nil restricted_token.revoked_at
  end

  test "destroy with invalid ref param does not revoke anything" do
    restricted_token = create_restricted_session(@staff)
    headers = as_staff_headers_with_token(@staff, restricted_token, host: @host)

    delete sign_org_in_session_url(ri: "jp"),
           params: { ref: "invalid_ref" },
           headers: headers

    assert_response :success # re-renders show
    restricted_token.reload

    assert_equal StaffToken::STATUS_RESTRICTED, restricted_token.status
  end

  test "destroy with ref belonging to another staff does not revoke" do
    other_staff = staffs(:two)
    StaffToken.where(staff: other_staff).delete_all
    other_token = StaffToken.create!(staff: other_staff, status: StaffToken::STATUS_ACTIVE)
    other_token.rotate_refresh_token!

    restricted_token = create_restricted_session(@staff)
    headers = as_staff_headers_with_token(@staff, restricted_token, host: @host)

    delete sign_org_in_session_url(ri: "jp"),
           params: { ref: other_token.signed_ref },
           headers: headers

    other_token.reload

    assert_nil other_token.expired_at
  end

  # ===================================================================
  # restricted session expiry (boundary analysis)
  # ===================================================================

  test "restricted session at 14 minutes is still accessible (boundary: within TTL)" do
    token = create_restricted_session(@staff, expires_at: 15.minutes.from_now)
    headers = as_staff_headers_with_token(@staff, token, host: @host)

    travel 14.minutes do
      get sign_org_in_session_url(ri: "jp"), headers: headers
    end

    assert_response :success
    token.reload

    assert_equal StaffToken::STATUS_RESTRICTED, token.status
  end

  test "restricted session expires after 15 minutes and is locked" do
    token = create_restricted_session(@staff, expires_at: 15.minutes.from_now)
    headers = as_staff_headers_with_token(@staff, token, host: @host)
    events = []

    travel 16.minutes do
      Rails.event.stub(
        :notify, lambda { |*args|
                   events << [args.first, args.last.is_a?(Hash) ? args.last : {}]
                 },
      ) do
        get sign_org_in_session_url(ri: "jp"), headers: headers
      end
    end

    assert_response :locked
    assert_equal "きんそくじこうです", response.body
    assert_not response.redirect?
    assert_includes events.map(&:first), "session.restricted.expired"
  end

  # ===================================================================
  # RestrictedSessionGuard -- non-session routes blocked for org
  # ===================================================================

  test "restricted session is blocked on non-session org routes" do
    token = create_restricted_session(@staff)
    headers = as_staff_headers_with_token(@staff, token, host: @host)

    # Try to access configuration page (not /in/sessions)
    get sign_org_configuration_url(ri: "jp"), headers: headers

    assert_response :locked
    assert_equal "きんそくじこうです", response.body
  end

  private

  def create_restricted_session(staff, expires_at: nil)
    token = StaffToken.create!(
      staff: staff,
      status: StaffToken::STATUS_RESTRICTED,
      staff_token_status_id: StaffTokenStatus::NOTHING,
      staff_token_kind_id: StaffTokenKind::BROWSER_WEB,
    )
    token.rotate_refresh_token!(expires_at: expires_at)
    token
  end

  def create_active_session(staff)
    token = StaffToken.create!(
      staff: staff,
      status: StaffToken::STATUS_ACTIVE,
      staff_token_status_id: StaffTokenStatus::NOTHING,
      staff_token_kind_id: StaffTokenKind::BROWSER_WEB,
    )
    token.rotate_refresh_token!
    token
  end

  def as_staff_headers_with_token(staff, token, host:)
    access_token = Authentication::Base::Token.encode(
      staff, host: host, session_public_id: token.public_id,
             resource_type: "staff",
    )
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
