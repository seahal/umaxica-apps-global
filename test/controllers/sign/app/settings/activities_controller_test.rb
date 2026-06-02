# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Settings::ActivitiesControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_email_statuses, :client_telephone_statuses,
           :client_chronicle_events, :client_chronicle_levels

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = clients(:one)
    @other_user = clients(:two)
    @headers = as_user_headers(@user, host: @host)

    ChronicleRecord.connected_to(role: :writing) do
      ClientChronicle.delete_all
    end
  end

  test "requires login and preserves ri parameter" do
    get sign_app_settings_activities_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :redirect
    assert_match(/ri=jp/, jump_rt_url_from_location(response.location))
  end

  test "shows only current user activity logs" do
    create_user_audit(
      user: @user,
      event_id: ClientChronicleEvent::LOGGED_IN,
      occurred_at: 2.minutes.ago,
      context: { tag: "my-login-event" },
    )
    create_user_audit(
      user: @other_user,
      event_id: ClientChronicleEvent::LOGGED_IN,
      occurred_at: 1.minute.ago,
      context: { tag: "other-user-event" },
    )

    get sign_app_settings_activities_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_includes response.body, "my-login-event"
    assert_not_includes response.body, "other-user-event"
  end

  test "orders activity by occurred_at desc" do
    create_user_audit(
      user: @user,
      event_id: ClientChronicleEvent::LOGGED_IN,
      occurred_at: 3.hours.ago,
      context: { tag: "oldest-entry" },
    )
    create_user_audit(
      user: @user,
      event_id: ClientChronicleEvent::LOGGED_IN,
      occurred_at: 2.hours.ago,
      context: { tag: "middle-entry" },
    )
    create_user_audit(
      user: @user,
      event_id: ClientChronicleEvent::LOGGED_IN,
      occurred_at: 1.hour.ago,
      context: { tag: "newest-entry" },
    )

    get sign_app_settings_activities_url(ri: "jp"), headers: @headers

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
        event_id: ClientChronicleEvent::LOGGED_IN,
        occurred_at: base_time + i.minutes,
        context: { tag: "limit-entry-#{i}" },
      )
    end

    get sign_app_settings_activities_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_includes response.body, "limit-entry-119"
    assert_includes response.body, "limit-entry-20"
    assert_not_includes response.body, "limit-entry-19"
    assert_not_includes response.body, "limit-entry-0"
  end

  test "filters to visible security events" do
    create_user_audit(
      user: @user,
      event_id: ClientChronicleEvent::LOGGED_IN,
      occurred_at: 2.minutes.ago,
      context: { tag: "login-success-event" },
    )
    create_user_audit(
      user: @user,
      event_id: ClientChronicleEvent::LOGGED_OUT,
      occurred_at: 110.seconds.ago,
      context: { tag: "logged-out-event" },
    )
    create_user_audit(
      user: @user,
      event_id: ClientChronicleEvent::SIGNED_UP_WITH_GOOGLE,
      occurred_at: 100.seconds.ago,
      context: { tag: "google-signup-event", auth_method: "social", provider: "google" },
    )
    create_user_audit(
      user: @user,
      event_id: ClientChronicleEvent::SOCIAL_LINKED,
      occurred_at: 95.seconds.ago,
      context: { tag: "social-linked-event", auth_method: "social", provider: "apple" },
    )
    create_user_audit(
      user: @user,
      event_id: ClientChronicleEvent::SOCIAL_UNLINKED,
      occurred_at: 92.seconds.ago,
      context: { tag: "social-unlinked-event", auth_method: "social", provider: "google" },
    )
    create_user_audit(
      user: @user,
      event_id: ClientChronicleEvent::SESSION_REVOKED,
      occurred_at: 90.seconds.ago,
      context: { tag: "session-revoked-event" },
    )
    create_user_audit(
      user: @user,
      event_id: ClientChronicleEvent::EMAIL_REGISTERED,
      occurred_at: 80.seconds.ago,
      context: { tag: "email-registered-event" },
    )
    create_user_audit(
      user: @user,
      event_id: ClientChronicleEvent::EMAIL_REMOVED,
      occurred_at: 70.seconds.ago,
      context: { tag: "email-removed-event" },
    )
    create_user_audit(
      user: @user,
      event_id: ClientChronicleEvent::TELEPHONE_REGISTERED,
      occurred_at: 60.seconds.ago,
      context: { tag: "telephone-registered-event" },
    )
    create_user_audit(
      user: @user,
      event_id: ClientChronicleEvent::TELEPHONE_REMOVED,
      occurred_at: 50.seconds.ago,
      context: { tag: "telephone-removed-event" },
    )
    create_user_audit(
      user: @user,
      event_id: ClientChronicleEvent::TOTP_ENABLED,
      occurred_at: 40.seconds.ago,
      context: { tag: "totp-enabled-event" },
    )
    create_user_audit(
      user: @user,
      event_id: ClientChronicleEvent::PASSKEY_REGISTERED,
      occurred_at: 30.seconds.ago,
      context: { tag: "passkey-registered-event" },
    )
    create_user_audit(
      user: @user,
      event_id: ClientChronicleEvent::USER_SECRET_CREATED,
      occurred_at: 20.seconds.ago,
      context: { tag: "user-secret_credential-created-event" },
    )
    create_user_audit(
      user: @user,
      event_id: ClientChronicleEvent::RECOVERY_CODES_GENERATED,
      occurred_at: 10.seconds.ago,
      context: { tag: "recovery-codes-generated-event" },
    )
    create_user_audit(
      user: @user,
      event_id: ClientChronicleEvent::ACCOUNT_WITHDRAWN,
      occurred_at: 1.minute.ago,
      context: { tag: "non-login-event" },
    )

    get sign_app_settings_activities_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_includes response.body, "login-success-event"
    assert_includes response.body, "logged-out-event"
    assert_includes response.body, I18n.t("sign.app.settings.activity.events.logged_out")
    assert_includes response.body, "google-signup-event"
    assert_includes response.body, I18n.t("sign.app.settings.activity.events.signed_up_with_google")
    assert_includes response.body, "social-linked-event"
    assert_includes response.body, I18n.t("sign.app.settings.activity.events.social_linked")
    assert_includes response.body, "social-unlinked-event"
    assert_includes response.body, I18n.t("sign.app.settings.activity.events.social_unlinked")
    assert_includes response.body, "session-revoked-event"
    assert_includes response.body, "email-registered-event"
    assert_includes response.body, I18n.t("sign.app.settings.activity.events.email_registered")
    assert_includes response.body, "email-removed-event"
    assert_includes response.body, I18n.t("sign.app.settings.activity.events.email_removed")
    assert_includes response.body, "telephone-registered-event"
    assert_includes response.body, I18n.t("sign.app.settings.activity.events.telephone_registered")
    assert_includes response.body, "telephone-removed-event"
    assert_includes response.body, I18n.t("sign.app.settings.activity.events.telephone_removed")
    assert_includes response.body, "totp-enabled-event"
    assert_includes response.body, I18n.t("sign.app.settings.activity.events.totp_enabled")
    assert_includes response.body, "passkey-registered-event"
    assert_includes response.body, I18n.t("sign.app.settings.activity.events.passkey_registered")
    assert_includes response.body, "user-secret_credential-created-event"
    assert_includes response.body, I18n.t("sign.app.settings.activity.events.user_secret_credential_created")
    assert_includes response.body, "recovery-codes-generated-event"
    assert_includes response.body, I18n.t("sign.app.settings.activity.events.recovery_codes_generated")
    assert_not_includes response.body, "non-login-event"
  end

  test "shows email removal logs recorded with email subject when actor is current user" do
    email = ClientEmail.create!(
      user: @user,
      address: "removed-activity@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    ClientChronicle.create!(
      actor_type: "Client",
      actor_id: @user.id,
      event_id: ClientChronicleEvent::EMAIL_REMOVED,
      level_id: ClientChronicleLevel::NOTHING,
      subject_id: email.id,
      subject_type: "ClientEmail",
      occurred_at: Time.current,
      context: { tag: "email-subject-removal" },
    )

    get sign_app_settings_activities_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_includes response.body, "email-subject-removal"
    assert_includes response.body, I18n.t("sign.app.settings.activity.events.email_removed")
  end

  test "shows telephone removal logs recorded with telephone subject when actor is current user" do
    telephone = ClientTelephone.create!(
      user: @user,
      number: "+10000000123",
      user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )
    ClientChronicle.create!(
      actor_type: "Client",
      actor_id: @user.id,
      event_id: ClientChronicleEvent::TELEPHONE_REMOVED,
      level_id: ClientChronicleLevel::NOTHING,
      subject_id: telephone.id,
      subject_type: "ClientTelephone",
      occurred_at: Time.current,
      context: { tag: "telephone-subject-removal" },
    )

    get sign_app_settings_activities_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_includes response.body, "telephone-subject-removal"
    assert_includes response.body, I18n.t("sign.app.settings.activity.events.telephone_removed")
  end

  test "renders user agent summary and login method" do
    create_user_audit(
      user: @user,
      event_id: ClientChronicleEvent::LOGGED_IN,
      occurred_at: Time.current,
      context: {
        tag: "ua-method-entry",
        user_agent: "Mozilla/5.0 (Macintosh) AppleWebKit/537.36 Chrome/124.0.0.0 Safari/537.36",
        auth_method: "passkey",
      },
    )

    get sign_app_settings_activities_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_includes response.body, "Chrome / Desktop"
    assert_includes response.body, "passkey"
  end

  test "renders social provider as login method when present" do
    create_user_audit(
      user: @user,
      event_id: ClientChronicleEvent::LOGGED_IN,
      occurred_at: Time.current,
      context: {
        tag: "social-login-entry",
        auth_method: "social",
        provider: "apple",
      },
    )

    get sign_app_settings_activities_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_includes response.body, "social-login-entry"
    assert_includes response.body, "apple"
  end

  private

  def create_user_audit(user:, event_id:, occurred_at:, context:, ip_address: "203.0.113.25")
    ClientChronicle.create!(
      actor_type: "Client",
      actor_id: user.id,
      user_chronicle_event: chronicle_event_for(event_id),
      user_chronicle_level: chronicle_level_for(ClientChronicleLevel::NOTHING),
      subject_id: user.id,
      subject_type: "Client",
      occurred_at: occurred_at,
      ip_address: ip_address,
      context: context,
    )
  end

  def chronicle_event_for(event_id)
    @chronicle_events_for_test ||= {}
    @chronicle_events_for_test[event_id] ||= ClientChronicleEvent.find(event_id)
  end

  def chronicle_level_for(level_id)
    @chronicle_levels_for_test ||= {}
    @chronicle_levels_for_test[level_id] ||= ClientChronicleLevel.find(level_id)
  end
end
