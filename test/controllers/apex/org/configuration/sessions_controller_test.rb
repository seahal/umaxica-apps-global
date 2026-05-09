# typed: false
# frozen_string_literal: true

require "test_helper"

class Apex::Org::Configuration::SessionsControllerTest < ActionDispatch::IntegrationTest
  fixtures :staffs, :staff_statuses, :staff_token_statuses, :staff_token_kinds

  setup do
    host! ENV.fetch("APEX_STAFF_URL", "www.org.localhost")
    @staff = staffs(:one)
    @host = ENV["APEX_STAFF_URL"] || "www.org.localhost"
    StaffToken.where(staff_id: @staff.id).delete_all
    @staff_token = StaffToken.create!(
      staff_id: @staff.id,
      staff_token_kind_id: StaffTokenKind::BROWSER_WEB,
      lapses_at: 1.day.from_now,
    )
    @headers = {
      "Host" => @host,
      "X-TEST-CURRENT-STAFF" => @staff.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @staff_token.public_id,
      "User-Agent" => AuthHelpers::MODERN_USER_AGENT,
    }.freeze
    @unauthenticated_headers = {
      "Host" => @host,
      "User-Agent" => AuthHelpers::MODERN_USER_AGENT,
    }.freeze
  end

  # ===================================================================
  # purge
  # ===================================================================

  test "purge user sessions" do
    user = users(:one)
    user_token = UserToken.create!(
      user_id: user.id,
      public_id: "purge_user_#{SecureRandom.hex(4)}",
      lapses_at: 1.day.from_now,
      user_token_kind_id: UserTokenKind::BROWSER_WEB,
    )

    post purge_apex_org_configuration_sessions_url,
         params: { target_type: "user", target_id: user.id },
         headers: @headers

    assert_response :see_other
    user_token.reload

    assert_not_nil user_token.lapses_at
  end

  test "purge staff sessions" do
    other_staff = staffs(:two)
    other_staff_token = StaffToken.create!(
      staff_id: other_staff.id,
      staff_token_kind_id: StaffTokenKind::BROWSER_WEB,
      lapses_at: 1.day.from_now,
    )

    post purge_apex_org_configuration_sessions_url,
         params: { target_type: "staff", target_id: other_staff.id },
         headers: @headers

    assert_response :see_other
    other_staff_token.reload

    assert_not_nil other_staff_token.lapses_at
  end

  test "purge customer sessions" do
    CustomerStatus.find_or_create_by!(id: CustomerStatus::ACTIVE)
    CustomerVisibility.find_or_create_by!(id: CustomerVisibility::CUSTOMER)
    CustomerTokenKind.find_or_create_by!(id: CustomerTokenKind::BROWSER_WEB)
    CustomerTokenBindingMethod.find_or_create_by!(id: CustomerTokenBindingMethod::NOTHING)
    CustomerTokenStatus.find_or_create_by!(id: CustomerTokenStatus::NOTHING)
    CustomerTokenDbscStatus.find_or_create_by!(id: CustomerTokenDbscStatus::NOTHING)
    customer = Customer.create!(
      status_id: CustomerStatus::ACTIVE,
      visibility_id: CustomerVisibility::CUSTOMER,
    )
    customer_token = CustomerToken.create!(
      customer: customer,
      customer_token_kind_id: CustomerTokenKind::BROWSER_WEB,
      customer_token_binding_method_id: CustomerTokenBindingMethod::NOTHING,
      customer_token_status_id: CustomerTokenStatus::NOTHING,
      customer_token_dbsc_status_id: CustomerTokenDbscStatus::NOTHING,
    )

    post purge_apex_org_configuration_sessions_url,
         params: { target_type: "customer", target_id: customer.id },
         headers: @headers

    assert_response :see_other
    customer_token.reload

    assert_not_nil customer_token.lapses_at
  end

  test "purge requires authentication" do
    user = users(:one)
    post purge_apex_org_configuration_sessions_url,
         params: { target_type: "user", target_id: user.id },
         headers: @unauthenticated_headers

    assert_response :redirect
  end

  test "purge records audit event" do
    user = users(:one)
    UserToken.create!(
      user_id: user.id,
      public_id: "purge_audit_#{SecureRandom.hex(4)}",
      lapses_at: 1.day.from_now,
      user_token_kind_id: UserTokenKind::BROWSER_WEB,
    )

    events = []
    subscriber = Object.new
    subscriber.define_singleton_method(:emit) { |event| events << event }
    Rails.event.subscribe(subscriber)

    post(
      purge_apex_org_configuration_sessions_url,
      params: { target_type: "user", target_id: user.id },
      headers: @headers,
    )

    assert_response :see_other
    purge_events = events.select { |e| e[:name] == "security.session_purge" }

    assert_operator purge_events.length, :>=, 1
    event = purge_events.last

    assert_equal "security.session_purge", event[:name]
    assert_equal "Staff", event[:payload][:actor_type]
    assert_equal "User", event[:payload][:target_type]
    assert_predicate event[:payload][:target_id], :present?
  ensure
    Rails.event.unsubscribe(subscriber) if defined?(subscriber) && subscriber
  end

  test "purge returns bad request for invalid target_type" do
    post purge_apex_org_configuration_sessions_url,
         params: { target_type: "invalid", target_id: 1 },
         headers: @headers

    assert_response :bad_request
  end
end
