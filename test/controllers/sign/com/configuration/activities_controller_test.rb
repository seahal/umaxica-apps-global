# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Configuration::ActivitiesControllerTest < ActionDispatch::IntegrationTest
  fixtures :client_chronicle_events, :client_chronicle_levels

  setup do
    host! ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @visitor = create_verified_visitor_with_email(email_address: "activities-#{SecureRandom.hex(4)}@example.com")
    @visitor.visitor_telephones.create!(
      number: "+10000000992",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    @token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    satisfy_visitor_verification(@token)

    ChronicleRecord.connected_to(role: :writing) do
      ClientChronicle.delete_all
    end
  end

  test "requires login and preserves ri parameter" do
    get sign_com_configuration_activities_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :redirect
    assert_match(/ri=jp/, jump_rt_url_from_location(response.location))
  end

  test "shows only current visitor activity logs" do
    create_user_audit(
      visitor: @visitor,
      event_id: ClientChronicleEvent::LOGGED_IN,
      occurred_at: 2.minutes.ago,
      context: { tag: "my-login-event" },
    )

    other_email = "activities-other-#{SecureRandom.hex(4)}@example.com"
    other_visitor = create_verified_visitor_with_email(email_address: other_email)
    create_user_audit(
      visitor: other_visitor,
      event_id: ClientChronicleEvent::LOGGED_IN,
      occurred_at: 1.minute.ago,
      context: { tag: "other-user-event" },
    )

    get sign_com_configuration_activities_url(ri: "jp"), headers: request_headers

    assert_response :success
    assert_includes response.body, "my-login-event"
    assert_not_includes response.body, "other-user-event"
  end

  test "orders activity by occurred_at desc" do
    create_user_audit(
      visitor: @visitor,
      event_id: ClientChronicleEvent::LOGGED_IN,
      occurred_at: 3.hours.ago,
      context: { tag: "oldest-entry" },
    )
    create_user_audit(
      visitor: @visitor,
      event_id: ClientChronicleEvent::LOGGED_IN,
      occurred_at: 2.hours.ago,
      context: { tag: "middle-entry" },
    )
    create_user_audit(
      visitor: @visitor,
      event_id: ClientChronicleEvent::LOGGED_IN,
      occurred_at: 1.hour.ago,
      context: { tag: "newest-entry" },
    )

    get sign_com_configuration_activities_url(ri: "jp"), headers: request_headers

    assert_response :success
    newest_pos = response.body.index("newest-entry")
    middle_pos = response.body.index("middle-entry")
    oldest_pos = response.body.index("oldest-entry")

    assert newest_pos && middle_pos && oldest_pos, "expected all entries to be present in response body"
    assert_operator newest_pos, :<, middle_pos
    assert_operator middle_pos, :<, oldest_pos
  end

  test "filters to login success events" do
    create_user_audit(
      visitor: @visitor,
      event_id: ClientChronicleEvent::LOGGED_IN,
      occurred_at: 2.minutes.ago,
      context: { tag: "login-success-event" },
    )
    create_user_audit(
      visitor: @visitor,
      event_id: ClientChronicleEvent::ACCOUNT_WITHDRAWN,
      occurred_at: 1.minute.ago,
      context: { tag: "non-login-event" },
    )

    get sign_com_configuration_activities_url(ri: "jp"), headers: request_headers

    assert_response :success
    assert_includes response.body, "login-success-event"
    assert_not_includes response.body, "non-login-event"
  end

  test "renders user agent summary and login method" do
    create_user_audit(
      visitor: @visitor,
      event_id: ClientChronicleEvent::LOGGED_IN,
      occurred_at: Time.current,
      context: {
        tag: "ua-method-entry",
        user_agent: "Mozilla/5.0 (Macintosh) AppleWebKit/537.36 Chrome/124.0.0.0 Safari/537.36",
        auth_method: "passkey",
      },
    )

    get sign_com_configuration_activities_url(ri: "jp"), headers: request_headers

    assert_response :success
    assert_includes response.body, "Chrome / Desktop"
    assert_includes response.body, "passkey"
  end

  test "helper methods cover labels ip addresses context and fallbacks" do
    controller = Sign::Com::Configuration::ActivitiesController.new
    controller.request = ActionDispatch::TestRequest.create

    known_activity = build_activity(
      event_id: ClientChronicleEvent::LOGIN_SUCCESS,
      ip_address: "203.0.113.25",
      context: {
        user_agent: "Mozilla/5.0 Firefox/120.0",
        auth_method: "email",
        note: "keep-me",
        secret_credential_token: "hide-me",
      },
    )
    unknown_activity = build_activity(event_id: 9999, ip_address: "", context: "bad")

    assert_equal I18n.t("sign.app.configuration.activity.events.logged_in"),
                 controller.send(:activity_event_label, known_activity)
    assert_includes controller.send(:activity_event_label, unknown_activity), "9999"
    assert_equal "203.0.113.x", controller.send(:activity_ip_address, known_activity)
    assert_equal "-", controller.send(:activity_ip_address, unknown_activity)
    assert_equal "{\"auth_method\":\"email\",\"note\":\"keep-me\"}",
                 controller.send(:activity_context_text, known_activity)
    assert_equal "{}", controller.send(:activity_context_text, unknown_activity)
    assert_equal "Firefox / Desktop", controller.send(:activity_user_agent_summary, known_activity)
    assert_equal "email", controller.send(:activity_login_method, known_activity)
    assert_equal "-", controller.send(:activity_login_method, unknown_activity)
    assert_equal "Tablet", controller.send(:detect_device_type, "Tablet")
  end

  private

  def request_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-RESOURCE" => @visitor.id,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end

  def create_user_audit(visitor:, event_id:, occurred_at:, context:, ip_address: "203.0.113.25")
    ClientChronicle.create!(
      actor_type: "Visitor",
      actor_id: visitor.id,
      event_id: event_id,
      level_id: ClientChronicleLevel::NOTHING,
      subject_id: visitor.id,
      subject_type: "Visitor",
      occurred_at: occurred_at,
      ip_address: ip_address,
      context: context,
    )
  end

  def build_activity(event_id:, ip_address:, context:)
    Struct.new(:event_id, :ip_address, :context, :occurred_at, :created_at, keyword_init: true).new(
      event_id: event_id,
      ip_address: ip_address,
      context: context,
      occurred_at: Time.current,
      created_at: Time.current,
    )
  end
end
