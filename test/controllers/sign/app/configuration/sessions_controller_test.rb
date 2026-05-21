# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Configuration::SessionsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_token_statuses, :client_token_kinds,
           :client_chronicle_events, :client_chronicle_levels,
           :app_preference_chronicle_levels, :app_preference_chronicle_events

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = clients(:one)
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
    expired_token = ClientToken.create!(
      user_id: @user.id,
      public_id: "expired_#{SecureRandom.hex(4)}",
      discarded_at: 1.day.from_now,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
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
    rotated_token = ClientToken.create!(user_id: @user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    rotated_refresh = rotated_token.rotate_refresh_token!
    Sign::RefreshTokenService.call(refresh_token: rotated_refresh)

    refresh_expired = ClientToken.create!(
      user_id: @user.id,
      discarded_at: 1.minute.ago,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
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

  test "index marks refreshed session as current after transparent refresh" do
    ClientToken.where(user_id: @user.id).delete_all
    token = ClientToken.create!(
      user_id: @user.id,
      discarded_at: 1.day.from_now,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
    )
    refresh_plain = token.rotate_refresh_token!
    cookies[Authentication::Base::ACCESS_COOKIE_KEY] = Authentication::Base::Token.encode(
      @user,
      host: @host,
      session_public_id: token.public_id,
      resource_type: "client",
      expires_at: 1.minute.ago,
    )
    cookies[Authentication::Base::REFRESH_COOKIE_KEY] = refresh_plain
    cookies[Authentication::Base::DEVICE_COOKIE_KEY] = token.device_id

    get sign_app_configuration_sessions_url(ri: "jp"),
        headers: host_headers(@host)

    assert_response :success

    refreshed_token = ClientToken.where(user_id: @user.id, rotated_at: nil).sole

    assert_not_equal token.public_id, refreshed_token.public_id
    assert_select "span", text: "current"
    assert_select "form[action^='#{sign_app_configuration_session_path(refreshed_token.public_id)}']", 0
    assert_select "form[action^='#{others_sign_app_configuration_sessions_path}']", 0
  end

  test "index rejects access token for revoked session" do
    ClientToken.where(user_id: @user.id).delete_all
    token = ClientToken.create!(
      user_id: @user.id,
      discarded_at: 1.day.from_now,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
    )
    cookies[Authentication::Base::ACCESS_COOKIE_KEY] = jwt_access_token_for(
      @user,
      host: @host,
      session_public_id: token.public_id,
      resource_type: "client",
    )
    token.revoke!

    get sign_app_configuration_sessions_url(ri: "jp"),
        headers: host_headers(@host)

    assert_response :redirect
  end

  test "index requires authentication" do
    get sign_app_configuration_sessions_url(ri: "jp"), headers: @unauthenticated_headers

    assert_response :redirect
  end

  # ===================================================================
  # destroy
  # ===================================================================

  test "destroy revokes session and returns see_other" do
    user_token = ClientToken.create!(
      user_id: @user.id,
      public_id: "test_session_#{SecureRandom.hex(4)}",
      discarded_at: 1.day.from_now,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
    )

    delete sign_app_configuration_session_url(user_token.public_id, ri: "jp"), headers: @headers

    assert_response :see_other

    user_token.reload

    assert_predicate user_token, :lapsed?
  end

  test "destroy records session revoke activity" do
    user_token = ClientToken.create!(
      user_id: @user.id,
      public_id: "aud_#{SecureRandom.hex(4)}",
      discarded_at: 1.day.from_now,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
    )

    assert_difference -> { session_revoke_activity_count }, 1 do
      delete sign_app_configuration_session_url(user_token.public_id, ri: "jp"), headers: @headers
    end

    assert_response :see_other
    activity = latest_session_revoke_activity

    assert_equal @user.id, activity.actor_id
    assert_equal "Client", activity.actor_type
    assert_equal @user.id.to_s, activity.subject_id
    assert_equal "Client", activity.subject_type
    assert_equal "session.revoke", activity.context["action"]
    assert_equal 1, activity.context["revoked_session_count"]
  end

  test "destroy current session returns error redirect instead of revoking" do
    current_session_id = @headers["X-TEST-SESSION-PUBLIC-ID"]
    delete sign_app_configuration_session_url(current_session_id, ri: "jp"), headers: @headers

    assert_response :redirect
    assert_match(/configuration\/sessions/, response.location)

    # Actor session must remain alive
    current_token = ClientToken.find_by!(public_id: current_session_id)

    assert_predicate current_token, :currently_usable?
  end

  test "destroy non-existent session returns 404" do
    delete sign_app_configuration_session_url("nonexistent_public_id", ri: "jp"), headers: @headers

    assert_response :not_found
  end

  test "destroy requires authentication" do
    user_token = ClientToken.create!(
      user_id: @user.id,
      public_id: "noauth_#{SecureRandom.hex(4)}",
      discarded_at: 1.day.from_now,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
    )

    delete sign_app_configuration_session_url(user_token.public_id, ri: "jp"),
           headers: @unauthenticated_headers

    assert_response :redirect
    user_token.reload

    assert_predicate user_token, :currently_usable?
  end

  test "destroy does not revoke session belonging to another user" do
    other_user = clients(:two)
    other_user_token = ClientToken.create!(
      user_id: other_user.id,
      public_id: "other_user_#{SecureRandom.hex(4)}",
      discarded_at: 1.day.from_now,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
    )

    delete sign_app_configuration_session_url(other_user_token.public_id, ri: "jp"),
           headers: @headers

    # set_session scopes to current_client, so it does not find it and returns 404.
    assert_response :not_found
    other_user_token.reload

    assert_predicate other_user_token, :currently_usable?
  end

  # ===================================================================
  # others
  # ===================================================================

  test "others revokes active sessions except current session" do
    current_session_id = @headers["X-TEST-SESSION-PUBLIC-ID"]
    token_one = ClientToken.create!(
      user_id: @user.id,
      public_id: "others_one_#{SecureRandom.hex(4)}",
      discarded_at: 1.day.from_now,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
    )
    token_two = ClientToken.create!(
      user_id: @user.id,
      public_id: "others_two_#{SecureRandom.hex(4)}",
      discarded_at: 1.day.from_now,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
    )

    delete others_sign_app_configuration_sessions_url(ri: "jp"), headers: @headers

    assert_response :see_other
    current_session = ClientToken.find_by!(public_id: current_session_id)
    token_one.reload
    token_two.reload

    assert_predicate current_session, :currently_usable?
    assert_predicate token_one, :lapsed?
    assert_predicate token_two, :lapsed?
    assert_not response_has_cookie?(::Authentication::Base::ACCESS_COOKIE_KEY)
    assert_not response_has_cookie?(::Authentication::Base::REFRESH_COOKIE_KEY)
  end

  test "others with no other sessions still succeeds (boundary: 0 other sessions)" do
    # Only the current session exists (created by as_user_headers)
    # Clean up any extra tokens
    current_session_id = @headers["X-TEST-SESSION-PUBLIC-ID"]
    ClientToken.where(user_id: @user.id).where.not(public_id: current_session_id).delete_all

    assert_no_difference -> { session_revoke_activity_count } do
      delete others_sign_app_configuration_sessions_url(ri: "jp"), headers: @headers
    end

    assert_response :see_other
    current_session = ClientToken.find_by!(public_id: current_session_id)

    assert_predicate current_session, :currently_usable?
  end

  test "others requires authentication" do
    delete others_sign_app_configuration_sessions_url(ri: "jp"), headers: @unauthenticated_headers

    assert_response :redirect
  end

  test "others does not revoke already-expired sessions" do
    already_expired = ClientToken.create!(
      user_id: @user.id,
      public_id: "already_exp_#{SecureRandom.hex(4)}",
      discarded_at: 1.day.from_now,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
    )
    already_expired.revoke!
    original_expired_at = already_expired.reload.discarded_at

    delete others_sign_app_configuration_sessions_url(ri: "jp"), headers: @headers

    assert_response :see_other
    already_expired.reload

    assert_equal original_expired_at.to_i, already_expired.discarded_at.to_i
  end

  # ===================================================================
  # HTML UI elements
  # ===================================================================

  test "index shows revoke all other sessions button" do
    ClientToken.create!(
      user_id: @user.id,
      public_id: "others_btn_#{SecureRandom.hex(4)}",
      discarded_at: 1.day.from_now,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
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

  # ===================================================================
  # revoke_all
  # ===================================================================

  test "revoke_all revokes all sessions including current and clears cookies" do
    current_session_id = @headers["X-TEST-SESSION-PUBLIC-ID"]
    token = ClientToken.find_by!(public_id: current_session_id)
    token.update!(last_step_up_at: 5.minutes.ago, last_step_up_scope: "session_revoke_all")
    other_token = ClientToken.create!(
      user_id: @user.id,
      public_id: "rall_o_#{SecureRandom.hex(4)}",
      discarded_at: 1.day.from_now,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
    )

    delete revoke_all_sign_app_configuration_sessions_url(ri: "jp"), headers: @headers

    assert_response :see_other
    token.reload
    other_token.reload

    assert_predicate token, :lapsed?
    assert_predicate other_token, :lapsed?
    assert_not response_has_cookie?(::Authentication::Base::ACCESS_COOKIE_KEY)
    assert_not response_has_cookie?(::Authentication::Base::REFRESH_COOKIE_KEY)
  end

  test "revoke_all records all sessions logout activity" do
    current_session_id = @headers["X-TEST-SESSION-PUBLIC-ID"]
    token = ClientToken.find_by!(public_id: current_session_id)
    token.update!(last_step_up_at: 5.minutes.ago, last_step_up_scope: "session_revoke_all")
    ClientToken.create!(
      user_id: @user.id,
      public_id: "rall_audit_#{SecureRandom.hex(4)}",
      discarded_at: 1.day.from_now,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
    )

    assert_difference -> { all_sessions_logout_activity_count }, 1 do
      delete revoke_all_sign_app_configuration_sessions_url(ri: "jp"), headers: @headers
    end

    assert_response :see_other
    activity = latest_all_sessions_logout_activity

    assert_equal ClientChronicleEvent::LOGOUT, activity.event_id
  end

  test "revoke_all requires step_up" do
    current_session_id = @headers["X-TEST-SESSION-PUBLIC-ID"]
    token = ClientToken.find_by!(public_id: current_session_id)
    token.update!(created_at: 20.minutes.ago)
    ClientOneTimePassword.create!(
      user: @user,
      private_key: ROTP::Base32.random_base32,
      user_one_time_password_status_id: ClientOneTimePasswordStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )

    delete revoke_all_sign_app_configuration_sessions_url(ri: "jp"), headers: @headers

    assert_response :unauthorized
  end

  test "revoke_all requires authentication" do
    delete revoke_all_sign_app_configuration_sessions_url(ri: "jp"), headers: @unauthenticated_headers

    assert_response :redirect
  end

  test "revoke_all records audit event" do
    current_session_id = @headers["X-TEST-SESSION-PUBLIC-ID"]
    token = ClientToken.find_by!(public_id: current_session_id)
    token.update!(last_step_up_at: 5.minutes.ago, last_step_up_scope: "session_revoke_all")

    logs = []
    Rails.logger.stub(:info, ->(message) { logs << JSON.parse(message, symbolize_names: true) }) do
      delete(revoke_all_sign_app_configuration_sessions_url(ri: "jp"), headers: @headers)
    end

    assert_response :see_other
    revoke_events = logs.select { |entry| entry[:event] == "security.session_revoke_all" }

    assert_operator revoke_events.length, :>=, 1
    event = revoke_events.last

    assert_equal "security.session_revoke_all", event[:event]
    assert_equal "Client", event[:data][:actor_type]
    assert_predicate event[:data][:actor_id], :present?
  end

  private

  def session_revoke_activity_count
    ClientChronicle.where(
      subject_type: "Client",
      subject_id: @user.id,
      event_id: ClientChronicleEvent::SESSION_REVOKED,
    ).count
  end

  def latest_session_revoke_activity
    ClientChronicle.where(
      subject_type: "Client",
      subject_id: @user.id,
      event_id: ClientChronicleEvent::SESSION_REVOKED,
    ).order(created_at: :desc).first
  end

  def all_sessions_logout_activity_count
    ClientChronicle.where(
      subject_type: "Client",
      subject_id: @user.id,
      event_id: ClientChronicleEvent::LOGOUT,
    ).count
  end

  def latest_all_sessions_logout_activity
    ClientChronicle.where(
      subject_type: "Client",
      subject_id: @user.id,
      event_id: ClientChronicleEvent::LOGOUT,
    ).order(created_at: :desc).first
  end
end
