# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/auth_helpers"

class Sign::Org::Configuration::SessionsControllerTest < ActionDispatch::IntegrationTest
  fixtures :staffs, :staff_statuses, :staff_token_statuses, :staff_token_kinds

  setup do
    host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = staffs(:one)
    @host = ENV["ID_STAFF_URL"] || "id.org.localhost"
    OperatorToken.where(staff_id: @staff.id).delete_all
    # Create a token for the current session
    @current_token = create_staff_session_token!
    @headers = {
      "Host" => @host,
      "X-TEST-CURRENT-STAFF" => @staff.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @current_token.public_id,
      "User-Agent" => AuthHelpers::MODERN_USER_AGENT,
    }.freeze
    @unauthenticated_headers = {
      "Host" => @host,
      "User-Agent" => AuthHelpers::MODERN_USER_AGENT,
    }.freeze
  end

  # ===================================================================
  # index
  # ===================================================================

  test "index returns active sessions as JSON" do
    get sign_org_configuration_sessions_url(ri: "jp", format: :json),
        headers: @headers.merge("Accept" => "application/json")

    assert_response :success
    body = response.parsed_body

    assert body.key?("sessions")
    assert body["sessions"].any? { |s| s["public_id"] == @current_token.public_id }
  end

  test "index excludes expired sessions from JSON response" do
    expired_token = create_staff_session_token!
    expired_token.revoke!

    get sign_org_configuration_sessions_url(ri: "jp", format: :json),
        headers: @headers.merge("Accept" => "application/json")

    assert_response :success
    body = response.parsed_body
    public_ids = body["sessions"].pluck("public_id")

    assert_not_includes public_ids, expired_token.public_id
  end

  test "index excludes rotated and refresh-expired sessions from JSON response" do
    OperatorToken.where(staff_id: @staff.id).where.not(id: @current_token.id).delete_all

    refresh_expired = create_staff_session_token!(lapses_at: 1.minute.ago)

    rotated_token = create_staff_session_token!
    rotated_refresh = rotated_token.rotate_refresh_token!
    Sign::RefreshTokenService.call(refresh_token: rotated_refresh)

    get sign_org_configuration_sessions_url(ri: "jp", format: :json),
        headers: @headers.merge("Accept" => "application/json")

    assert_response :success
    public_ids = response.parsed_body["sessions"].pluck("public_id")

    assert_not_includes public_ids, rotated_token.reload.public_id
    assert_not_includes public_ids, refresh_expired.public_id
  end

  test "index returns HTML by default" do
    get sign_org_configuration_sessions_url(ri: "jp"), headers: @headers

    assert_response :success
  end

  test "index requires authentication" do
    get sign_org_configuration_sessions_url(ri: "jp"), headers: @unauthenticated_headers

    assert_response :redirect
  end

  # ===================================================================
  # destroy
  # ===================================================================

  test "destroy revokes other session and redirects with see_other" do
    other_token = create_staff_session_token!

    delete sign_org_configuration_session_url(other_token.public_id, ri: "jp"), headers: @headers

    assert_response :see_other
    other_token.reload

    assert_predicate other_token, :lapsed?
  end

  test "destroy current session returns error redirect instead of revoking" do
    delete sign_org_configuration_session_url(@current_token.public_id, ri: "jp"), headers: @headers

    assert_response :redirect
    assert_match(/configuration\/sessions/, response.location)

    # Actor session must remain alive
    @current_token.reload

    assert_predicate @current_token, :currently_usable?
  end

  test "destroy non-existent session returns 404" do
    delete sign_org_configuration_session_url("nonexistent_public_id", ri: "jp"), headers: @headers

    assert_response :not_found
  end

  test "destroy requires authentication" do
    other_token = create_staff_session_token!

    delete sign_org_configuration_session_url(other_token.public_id, ri: "jp"),
           headers: @unauthenticated_headers

    assert_response :redirect
    other_token.reload

    assert_predicate other_token, :currently_usable?
  end

  test "destroy does not revoke session belonging to another staff" do
    other_staff = staffs(:two)
    other_staff_token = create_staff_session_token!(staff: other_staff)

    # Try to destroy another staff's token using current staff's session
    delete sign_org_configuration_session_url(other_staff_token.public_id, ri: "jp"),
           headers: @headers

    # set_session scopes to current_staff so it won't find it -- 404
    assert_response :not_found
    other_staff_token.reload

    assert_predicate other_staff_token, :currently_usable?
  end

  # ===================================================================
  # others
  # ===================================================================

  test "others revokes all sessions except current" do
    other_token = create_staff_session_token!

    delete others_sign_org_configuration_sessions_url(ri: "jp"), headers: @headers

    assert_response :see_other

    @current_token.reload
    other_token.reload

    assert_predicate @current_token, :currently_usable?
    assert_predicate other_token, :lapsed?
  end

  test "others with no other sessions still succeeds (boundary: 0 other sessions)" do
    # Only the current session exists
    delete others_sign_org_configuration_sessions_url(ri: "jp"), headers: @headers

    assert_response :see_other
    @current_token.reload

    assert_predicate @current_token, :currently_usable?
  end

  test "others requires authentication" do
    delete others_sign_org_configuration_sessions_url(ri: "jp"), headers: @unauthenticated_headers

    assert_response :redirect
  end

  test "others does not revoke already-expired sessions" do
    already_expired = create_staff_session_token!
    already_expired.revoke!
    original_expired_at = already_expired.reload.lapses_at

    delete others_sign_org_configuration_sessions_url(ri: "jp"), headers: @headers

    assert_response :see_other
    already_expired.reload
    # expired_at should not change (already filtered out by visible session scope)
    assert_equal original_expired_at.to_i, already_expired.lapses_at.to_i
  end

  # ===================================================================
  # HTML UI elements
  # ===================================================================

  test "index shows revoke all other sessions button" do
    create_staff_session_token!

    get sign_org_configuration_sessions_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_select "form[action^='#{others_sign_org_configuration_sessions_path}']"
    assert_select "button", text: "他のセッションをすべて削除"
  end

  test "index shows back link on index page" do
    get sign_org_configuration_sessions_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_select "a[href=?]", sign_org_configuration_path(ri: "jp")
  end

  test "index marks the current session" do
    get sign_org_configuration_sessions_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_includes response.body, "current"
    assert_includes response.body, @current_token.public_id
  end

  # ===================================================================
  # revoke_all
  # ===================================================================

  test "revoke_all revokes all sessions including current and clears cookies" do
    @current_token.update!(last_step_up_at: 5.minutes.ago, last_step_up_scope: "session_revoke_all")
    other_token = create_staff_session_token!

    delete revoke_all_sign_org_configuration_sessions_url(ri: "jp"), headers: @headers

    assert_response :see_other
    @current_token.reload
    other_token.reload

    assert_predicate @current_token, :lapsed?
    assert_predicate other_token, :lapsed?
    assert_not response_has_cookie?(::Authentication::Base::ACCESS_COOKIE_KEY)
    assert_not response_has_cookie?(::Authentication::Base::REFRESH_COOKIE_KEY)
  end

  test "revoke_all requires step_up" do
    @current_token.update!(created_at: 20.minutes.ago)
    delete revoke_all_sign_org_configuration_sessions_url(ri: "jp"), headers: @headers

    assert_response :unauthorized
  end

  test "revoke_all requires authentication" do
    delete revoke_all_sign_org_configuration_sessions_url(ri: "jp"), headers: @unauthenticated_headers

    assert_response :redirect
  end

  test "revoke_all records audit event" do
    @current_token.update!(last_step_up_at: 5.minutes.ago, last_step_up_scope: "session_revoke_all")

    events = []
    subscriber = Object.new
    subscriber.define_singleton_method(:emit) { |event| events << event }
    Rails.event.subscribe(subscriber)

    delete(revoke_all_sign_org_configuration_sessions_url(ri: "jp"), headers: @headers)

    assert_response :see_other
    revoke_events = events.select { |e| e[:name] == "security.session_revoke_all" }

    assert_operator revoke_events.length, :>=, 1
    event = revoke_events.last

    assert_equal "security.session_revoke_all", event[:name]
    assert_equal "Operator", event[:payload][:actor_type]
    assert_predicate event[:payload][:actor_id], :present?
  ensure
    Rails.event.unsubscribe(subscriber) if defined?(subscriber) && subscriber
  end

  private

  def create_staff_session_token!(staff: @staff, **attributes)
    token = OperatorToken.new(
      {
        staff_id: staff.id,
        staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
        lapses_at: 1.day.from_now,
      }.merge(attributes),
    )
    token.save!(validate: false)
    token
  end
end
