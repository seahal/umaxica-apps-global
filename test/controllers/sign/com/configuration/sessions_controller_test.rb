# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Configuration::SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    CustomerStatus.find_or_create_by!(id: CustomerStatus::ACTIVE)
    CustomerVisibility.find_or_create_by!(id: CustomerVisibility::CUSTOMER)
    CustomerEmailStatus.find_or_create_by!(id: CustomerEmailStatus::VERIFIED)
    CustomerTelephoneStatus.find_or_create_by!(id: CustomerTelephoneStatus::VERIFIED)
    CustomerTokenKind.find_or_create_by!(id: CustomerTokenKind::BROWSER_WEB)
    CustomerTokenBindingMethod.find_or_create_by!(id: CustomerTokenBindingMethod::NOTHING)
    CustomerTokenStatus.find_or_create_by!(id: CustomerTokenStatus::NOTHING)
    CustomerTokenDbscStatus.find_or_create_by!(id: CustomerTokenDbscStatus::NOTHING)
    @customer = Customer.create!(
      status_id: CustomerStatus::ACTIVE,
      visibility_id: CustomerVisibility::CUSTOMER,
    )
    CustomerEmail.create!(
      customer: @customer,
      address: "com-sessions-#{SecureRandom.hex(4)}@example.com",
      customer_email_status_id: CustomerEmailStatus::VERIFIED,
      confirm_policy: "1",
    )
    @customer.customer_telephones.create!(
      number: "+819000000003",
      customer_telephone_status_id: CustomerTelephoneStatus::VERIFIED,
    )
    @token = CustomerToken.create!(
      customer: @customer,
      customer_token_kind_id: CustomerTokenKind::BROWSER_WEB,
      customer_token_binding_method_id: CustomerTokenBindingMethod::NOTHING,
      customer_token_status_id: CustomerTokenStatus::NOTHING,
      customer_token_dbsc_status_id: CustomerTokenDbscStatus::NOTHING,
    )
    satisfy_customer_verification(@token)
    @other_session = CustomerToken.create!(
      customer: @customer,
      customer_token_kind_id: CustomerTokenKind::BROWSER_WEB,
      customer_token_binding_method_id: CustomerTokenBindingMethod::NOTHING,
      customer_token_status_id: CustomerTokenStatus::NOTHING,
      customer_token_dbsc_status_id: CustomerTokenDbscStatus::NOTHING,
    )
  end

  def request_headers(token = @token)
    {
      "Host" => @host,
      "X-TEST-CURRENT-RESOURCE" => @customer.id,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end

  test "index returns html and json" do
    get sign_com_configuration_sessions_url(ri: "jp", format: :json), headers: request_headers

    assert_response :success
    assert_includes response.parsed_body["sessions"].pluck("public_id"), @token.public_id
  end

  test "destroy rejects current session and missing session returns not found" do
    delete sign_com_configuration_session_url(@token.public_id, ri: "jp"), headers: request_headers

    assert_redirected_to sign_com_configuration_sessions_url(ri: "jp")
    assert_equal I18n.t("sign.app.configuration.sessions.revoke.failure"), flash[:alert]

    delete sign_com_configuration_session_url("missing", ri: "jp"), headers: request_headers

    assert_response :not_found
  end

  test "destroy revokes another session and others revokes all others" do
    delete sign_com_configuration_session_url(@other_session.public_id, ri: "jp"), headers: request_headers

    assert_redirected_to sign_com_configuration_sessions_url(ri: "jp")

    @other_session.reload

    assert_predicate @other_session, :revoked?

    other_two = CustomerToken.create!(customer: @customer, customer_token_kind_id: CustomerTokenKind::BROWSER_WEB)

    delete others_sign_com_configuration_sessions_url(ri: "jp"), headers: request_headers

    assert_redirected_to sign_com_configuration_sessions_url(ri: "jp")

    assert_predicate other_two.reload, :revoked?
  end

  # ===================================================================
  # revoke_all
  # ===================================================================

  test "revoke_all revokes all sessions including current and clears cookies" do
    @token.update!(last_step_up_at: 5.minutes.ago, last_step_up_scope: "session_revoke_all")

    delete revoke_all_sign_com_configuration_sessions_url(ri: "jp"), headers: request_headers

    assert_response :see_other
    @token.reload
    @other_session.reload

    assert_predicate @token, :lapsed?
    assert_predicate @other_session, :lapsed?
    assert_not response_has_cookie?(::Authentication::Base::ACCESS_COOKIE_KEY)
    assert_not response_has_cookie?(::Authentication::Base::REFRESH_COOKIE_KEY)
  end

  test "revoke_all requires step_up" do
    @token.update!(created_at: 20.minutes.ago)
    delete revoke_all_sign_com_configuration_sessions_url(ri: "jp"), headers: request_headers

    assert_response :unauthorized
  end

  test "revoke_all requires authentication" do
    delete revoke_all_sign_com_configuration_sessions_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :redirect
  end

  test "revoke_all records audit event" do
    @token.update!(last_step_up_at: 5.minutes.ago, last_step_up_scope: "session_revoke_all")

    events = []
    subscriber = Object.new
    subscriber.define_singleton_method(:emit) { |event| events << event }
    Rails.event.subscribe(subscriber)

    delete(revoke_all_sign_com_configuration_sessions_url(ri: "jp"), headers: request_headers)

    assert_response :see_other
    revoke_events = events.select { |e| e[:name] == "security.session_revoke_all" }

    assert_operator revoke_events.length, :>=, 1
    event = revoke_events.last

    assert_equal "security.session_revoke_all", event[:name]
    assert_equal "Customer", event[:payload][:actor_type]
    assert_predicate event[:payload][:actor_id], :present?
  ensure
    Rails.event.unsubscribe(subscriber) if defined?(subscriber) && subscriber
  end
end
