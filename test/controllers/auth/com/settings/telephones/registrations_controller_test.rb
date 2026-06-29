# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class Auth::Com::Settings::Telephones::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    host! ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")
    @host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")
    @visitor = create_verified_visitor_with_email(email_address: "registration-#{SecureRandom.hex(4)}@example.com")
    @token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    satisfy_visitor_verification(@token)
    @token.update!(last_step_up_at: Time.current, last_step_up_scope: "settings_telephone")

    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  def request_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-RESOURCE" => @visitor.id,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end

  def request_headers_for(visitor, token)
    {
      "Host" => @host,
      "X-TEST-CURRENT-RESOURCE" => visitor.id,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end

  test "new does not require step-up while registering first telephone" do
    visitor = create_verified_visitor_with_email(email_address: "first-telephone-#{SecureRandom.hex(4)}@example.com")
    token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)

    get(
      new_auth_com_settings_telephones_registration_url(
        ri: "jp",
      ),
      headers: request_headers_for(visitor, token),
    )

    assert_response :success
  end

  test "new requires step-up when visitor already has verified telephone" do
    visitor = create_verified_visitor_with_email(email_address: "existing-telephone-#{SecureRandom.hex(4)}@example.com")
    visitor.visitor_telephones.create!(
      raw_number: "+10000000040",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)

    get(
      new_auth_com_settings_telephones_registration_url(ri: "jp"),
      headers: request_headers_for(visitor, token),
    )

    assert_response :redirect
    assert_match(%r{/verification}, response.location)
    assert_includes response.location, "scope=settings_telephone"
  end

  test "create registers telephone for current visitor" do
    get(
      new_auth_com_settings_telephones_registration_url(
        ri: "jp",
      ),
      headers: request_headers,
    )
    assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
      assert_difference("VisitorTelephone.count", 1) do
        post auth_com_settings_telephones_registration_url(ri: "jp"),
             params: { user_telephone: { raw_number: "+10000000039" } },
             headers: request_headers
      end
    end

    assert_response :redirect
    assert_redirected_to edit_auth_com_settings_telephones_registration_url(ri: "jp")

    visitor_telephone = VisitorTelephone.order(created_at: :desc).first

    assert_equal @visitor.id, visitor_telephone.visitor_id
    assert_equal VisitorTelephoneStatus::UNVERIFIED, visitor_telephone.visitor_telephone_status_id
  end

  test "new renders stealth turnstile" do
    get(
      new_auth_com_settings_telephones_registration_url(
        ri: "jp",
      ),
      headers: request_headers,
    )

    assert_response :success
    assert_select "input[name='cf-turnstile-response'][type='hidden']", count: 1
    assert_includes response.body, 'data-turnstile-mode-value="execute"'
  end

  test "edit renders authentication code copy" do
    telephone = VisitorTelephone.create!(
      visitor: @visitor,
      raw_number: "+18888888888",
      visitor_telephone_status_id: VisitorTelephoneStatus::UNVERIFIED,
      otp_private_key: "secret_credential",
      otp_expires_at: 10.minutes.from_now,
    )

    with_current_registration_telephone(telephone) do
      get edit_auth_com_settings_telephones_registration_url(ri: "jp"),
          headers: request_headers
    end

    assert_response :success
    assert_select "h1", text: I18n.t("sign.app.registration.telephone.edit.page_title")
    assert_select "label", text: I18n.t("sign.app.registration.telephone.edit.code_label")
    assert_select "input[placeholder=?]", I18n.t("sign.app.registration.telephone.edit.code_placeholder")
    assert_select "input[type=submit][value=?]", I18n.t("sign.app.registration.telephone.edit.submit")
    assert_includes response.body, "電話番号"
    assert_includes response.body, "SMS"
    assert_includes response.body, I18n.t("sign.app.registration.telephone.edit.delivery_help")
  end

  test "update successfully verifies telephone" do
    telephone = VisitorTelephone.create!(
      visitor: @visitor,
      raw_number: "+19999999999",
      visitor_telephone_status_id: VisitorTelephoneStatus::UNVERIFIED,
      otp_private_key: "secret_credential",
      otp_expires_at: 10.minutes.from_now,
    )

    with_current_registration_telephone(telephone) do
      original_method =
        Auth::Com::Settings::Telephones::RegistrationsController
          .instance_method(:complete_visitor_telephone_verification)
      Auth::Com::Settings::Telephones::RegistrationsController
        .define_method(:complete_visitor_telephone_verification) do |*_args|
        :success
      end

      patch(
        auth_com_settings_telephones_registration_url(ri: "jp"),
        params: { user_telephone: { pass_code: "123456" } },
        headers: request_headers,
      )
    ensure
      Auth::Com::Settings::Telephones::RegistrationsController.define_method(
        :complete_visitor_telephone_verification,
        original_method,
      )
    end

    assert_redirected_to auth_com_settings_telephones_url(
      ri: "jp",
      host: ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost"),
    )
    assert_equal VisitorTelephoneStatus::VERIFIED, telephone.reload.visitor_telephone_status_id
  end

  private

  def with_current_registration_telephone(telephone)
    original_method =
      Auth::Com::Settings::Telephones::RegistrationsController.instance_method(:current_registration_telephone)
    Auth::Com::Settings::Telephones::RegistrationsController.define_method(:current_registration_telephone) do
      telephone
    end

    yield
  ensure
    Auth::Com::Settings::Telephones::RegistrationsController.define_method(
      :current_registration_telephone,
      original_method,
    )
  end
end
