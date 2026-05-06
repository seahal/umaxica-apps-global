# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Configuration::ActivitiesControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :user_statuses, :user_chronicle_events, :user_chronicle_levels

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = users(:one)
    @other_user = users(:two)
    @headers = as_user_headers(@user, host: @host)

    ChronicleRecord.connected_to(role: :writing) do
      UserChronicle.delete_all
    end
  end

  test "requires login and preserves ri parameter" do
    get sign_app_configuration_activities_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :redirect
    assert_match(/ri=jp/, response.headers["Location"])
  end

  test "shows only current user activity logs" do
    create_user_audit(
      user: @user,
      event_id: UserChronicleEvent::LOGGED_IN,
      occurred_at: 2.minutes.ago,
      context: { tag: "my-login-event" },
    )
    create_user_audit(
      user: @other_user,
      event_id: UserChronicleEvent::LOGGED_IN,
      occurred_at: 1.minute.ago,
      context: { tag: "other-user-event" },
    )

    get sign_app_configuration_activities_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_includes response.body, "my-login-event"
    assert_not_includes response.body, "other-user-event"
  end

  test "orders activity by occurred_at desc" do
    create_user_audit(
      user: @user,
      event_id: UserChronicleEvent::LOGGED_IN,
      occurred_at: 3.hours.ago,
      context: { tag: "oldest-entry" },
    )
    create_user_audit(
      user: @user,
      event_id: UserChronicleEvent::LOGGED_IN,
      occurred_at: 2.hours.ago,
      context: { tag: "middle-entry" },
    )
    create_user_audit(
      user: @user,
      event_id: UserChronicleEvent::LOGGED_IN,
      occurred_at: 1.hour.ago,
      context: { tag: "newest-entry" },
    )

    get sign_app_configuration_activities_url(ri: "jp"), headers: @headers

    assert_response :success
    newest_pos = response.body.index("newest-entry")
    middle_pos = response.body.index("middle-entry")
    oldest_pos = response.body.index("oldest-entry")

    assert newest_pos && middle_pos && oldest_pos, "expected all entries to be present in response body"
    assert_operator newest_pos, :<, middle_pos
    assert_operator middle_pos, :<, oldest_pos
  end

  test "applies limit 100" do
    base_time = Time.current.change(usec: 0)
    120.times do |i|
      create_user_audit(
        user: @user,
        event_id: UserChronicleEvent::LOGGED_IN,
        occurred_at: base_time + i.minutes,
        context: { tag: "limit-entry-#{i}" },
      )
    end

    get sign_app_configuration_activities_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_includes response.body, "limit-entry-119"
    assert_includes response.body, "limit-entry-20"
    assert_not_includes response.body, "limit-entry-19"
    assert_not_includes response.body, "limit-entry-0"
  end

  test "filters to login success events" do
    create_user_audit(
      user: @user,
      event_id: UserChronicleEvent::LOGGED_IN,
      occurred_at: 2.minutes.ago,
      context: { tag: "login-success-event" },
    )
    create_user_audit(
      user: @user,
      event_id: UserChronicleEvent::ACCOUNT_WITHDRAWN,
      occurred_at: 1.minute.ago,
      context: { tag: "non-login-event" },
    )

    get sign_app_configuration_activities_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_includes response.body, "login-success-event"
    assert_not_includes response.body, "non-login-event"
  end

  test "renders user agent summary and login method" do
    create_user_audit(
      user: @user,
      event_id: UserChronicleEvent::LOGGED_IN,
      occurred_at: Time.current,
      context: {
        tag: "ua-method-entry",
        user_agent: "Mozilla/5.0 (Macintosh) AppleWebKit/537.36 Chrome/124.0.0.0 Safari/537.36",
        auth_method: "passkey",
      },
    )

    get sign_app_configuration_activities_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_includes response.body, "Chrome / Desktop"
    assert_includes response.body, "passkey"
  end

  private

  def create_user_audit(user:, event_id:, occurred_at:, context:, ip_address: "203.0.113.25")
    UserChronicle.create!(
      actor_type: "User",
      actor_id: user.id,
      event_id: event_id,
      level_id: UserChronicleLevel::NOTHING,
      subject_id: user.id,
      subject_type: "User",
      occurred_at: occurred_at,
      ip_address: ip_address,
      context: context,
    )
  end
end
