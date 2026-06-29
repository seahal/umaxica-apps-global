# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class Auth::Com::Settings::EmailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")
    @acme_host = ENV.fetch("PRIVATE_ACME_CORPORATE_URL", "www.com.localhost")
    @visitor = create_verified_visitor_with_email(email_address: "settings-emails-#{SecureRandom.hex(4)}@example.com")
    @visitor.visitor_telephones.create!(
      number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    @token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    mark_token_step_up_satisfied_for_test(@token, scope: "settings_email")
    host! @host
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "sign settings emails index renders sign settings authority" do
    get auth_com_settings_emails_url(ri: "jp"), headers: session_headers

    assert_response :success
  end

  test "sign settings email edit loads owned email" do
    email = @visitor.visitor_emails.first

    get edit_auth_com_settings_email_url(email.public_id, ri: "jp"), headers: session_headers

    assert_response :success
  end

  test "sign settings email update mutates local preference fields" do
    visitor = @visitor
    email = VisitorEmail.create!(
      visitor: visitor,
      address: "sign-com-email-update-redirect@example.com",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      confirm_policy: true,
      promotional: true,
      notifiable: true,
    )

    assert_changes -> { email.reload.attributes.slice("promotional", "notifiable") } do
      patch auth_com_settings_email_url(email.public_id, ri: "jp"),
            params: { visitor_email: { promotional: "0", notifiable: "0" } },
            headers: session_headers
    end

    assert_redirected_to edit_auth_com_settings_email_url(email.public_id, ri: "jp")
  end

  test "sign settings email destroy mutates local account email" do
    visitor = @visitor
    email = VisitorEmail.create!(
      visitor: visitor,
      address: "sign-com-email-destroy-redirect@example.com",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      confirm_policy: true,
    )

    assert_difference("VisitorEmail.count", -1) do
      delete auth_com_settings_email_url(email.public_id, ri: "jp"), headers: session_headers
    end

    assert_redirected_to auth_com_settings_emails_url(ri: "jp")
  end

  test "sign email registration route remains on sign ceremony surface" do
    get new_auth_com_settings_emails_registration_url(ri: "jp"), headers: session_headers

    assert_equal "auth/com/settings/emails/registrations", @request.path_parameters[:controller]
    assert_equal "new", @request.path_parameters[:action]
  end

  private

  def session_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-RESOURCE" => @visitor.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end
end
