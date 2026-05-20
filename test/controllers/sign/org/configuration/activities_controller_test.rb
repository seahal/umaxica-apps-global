# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Configuration::ActivitiesControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_identity_statuses, :operator_chronicle_events, :operator_chronicle_levels

  setup do
    host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = operators(:one)
    @other_staff = operators(:two)
    @headers = as_staff_headers(@staff, host: @host)

    ChronicleRecord.connected_to(role: :writing) do
      OperatorChronicle.delete_all
    end
  end

  test "requires login and preserves ri parameter" do
    get sign_org_configuration_activities_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :redirect
    assert_match(/ri=jp/, response.headers["Location"])
  end

  test "shows only current staff activity logs" do
    create_staff_audit(
      staff: @staff, event_id: OperatorChronicleEvent::LOGGED_IN, occurred_at: 2.minutes.ago,
      context: { tag: "my-login-event" },
    )
    create_staff_audit(
      staff: @other_staff, event_id: OperatorChronicleEvent::LOGGED_IN, occurred_at: 1.minute.ago,
      context: { tag: "other-staff-event" },
    )

    get sign_org_configuration_activities_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_includes response.body, "my-login-event"
    assert_not_includes response.body, "other-staff-event"
  end

  test "orders activity by occurred_at desc" do
    create_staff_audit(
      staff: @staff, event_id: OperatorChronicleEvent::LOGGED_IN, occurred_at: 3.hours.ago,
      context: { tag: "oldest-entry" },
    )
    create_staff_audit(
      staff: @staff, event_id: OperatorChronicleEvent::LOGGED_IN, occurred_at: 2.hours.ago,
      context: { tag: "middle-entry" },
    )
    create_staff_audit(
      staff: @staff, event_id: OperatorChronicleEvent::LOGGED_IN, occurred_at: 1.hour.ago,
      context: { tag: "newest-entry" },
    )

    get sign_org_configuration_activities_url(ri: "jp"), headers: @headers

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
      create_staff_audit(
        staff: @staff,
        event_id: OperatorChronicleEvent::LOGGED_IN,
        occurred_at: base_time + i.minutes,
        context: { tag: "limit-entry-#{i}" },
      )
    end

    get sign_org_configuration_activities_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_includes response.body, "limit-entry-119"
    assert_includes response.body, "limit-entry-20"
    assert_not_includes response.body, "limit-entry-19"
    assert_not_includes response.body, "limit-entry-0"
  end

  test "filters to login success events" do
    create_staff_audit(
      staff: @staff, event_id: OperatorChronicleEvent::LOGGED_IN, occurred_at: 2.minutes.ago,
      context: { tag: "login-success-event" },
    )
    create_staff_audit(
      staff: @staff, event_id: OperatorChronicleEvent::LOGGED_OUT, occurred_at: 1.minute.ago,
      context: { tag: "non-login-event" },
    )

    get sign_org_configuration_activities_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_includes response.body, "login-success-event"
    assert_not_includes response.body, "non-login-event"
  end

  test "shows social unlink events" do
    create_staff_audit(
      staff: @staff,
      event_id: OperatorChronicleEvent::SOCIAL_UNLINKED,
      occurred_at: 1.minute.ago,
      context: { tag: "org-social-unlinked-event", auth_method: "social", provider: "google" },
    )

    get sign_org_configuration_activities_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_includes response.body, "org-social-unlinked-event"
    assert_includes response.body, I18n.t("sign.org.configuration.activity.events.social_unlinked")
  end

  test "renders user agent summary and login method" do
    create_staff_audit(
      staff: @staff,
      event_id: OperatorChronicleEvent::LOGGED_IN,
      occurred_at: Time.current,
      context: {
        tag: "ua-method-entry",
        user_agent: "Mozilla/5.0 (Macintosh) AppleWebKit/537.36 Chrome/124.0.0.0 Safari/537.36",
        auth_method: "passkey",
      },
    )

    get sign_org_configuration_activities_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_includes response.body, "Chrome / Desktop"
    assert_includes response.body, "passkey"
  end

  private

  def create_staff_audit(staff:, event_id:, occurred_at:, context:, ip_address: "203.0.113.25")
    OperatorChronicle.create!(
      actor_type: "Operator",
      actor_id: staff.id,
      staff_chronicle_event: staff_chronicle_event_for(event_id),
      staff_chronicle_level: staff_chronicle_level_for,
      subject_id: staff.id,
      subject_type: "Operator",
      occurred_at: occurred_at,
      discarded_at: 1.year.from_now,
      ip_address: ip_address,
      context: context,
    )
  end

  def staff_chronicle_event_for(event_id)
    @operator_chronicle_events ||= {}
    @operator_chronicle_events[event_id] ||= OperatorChronicleEvent.find(event_id)
  end

  def staff_chronicle_level_for
    @staff_chronicle_level ||= OperatorChronicleLevel.find(OperatorChronicleLevel::NOTHING)
  end
end
