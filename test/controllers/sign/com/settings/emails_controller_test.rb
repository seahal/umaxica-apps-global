# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Settings::EmailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost")
    @acme_host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    @visitor = create_verified_visitor_with_email(email_address: "settings-emails-#{SecureRandom.hex(4)}@example.com")
    @visitor.visitor_telephones.create!(
      number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    @token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    host! @host
  end

  test "sign settings emails index redirects to acme authority" do
    get sign_com_settings_emails_url(ri: "jp"), headers: session_headers

    assert_redirected_to acme_com_settings_emails_url(ri: "jp", host: @acme_host)
  end

  test "sign settings email edit redirects without loading email" do
    get edit_sign_com_settings_email_url("missing", ri: "jp"), headers: session_headers

    assert_redirected_to edit_acme_com_settings_email_url("missing", ri: "jp", host: @acme_host)
  end

  test "sign settings email update redirects without local preference mutation" do
    visitor = create_verified_visitor_with_email(email_address: "sign-com-email-owner@example.com")
    email = VisitorEmail.create!(
      visitor: visitor,
      address: "sign-com-email-update-redirect@example.com",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      confirm_policy: true,
      promotional: true,
      notifiable: true,
    )

    assert_no_changes -> { email.reload.attributes.slice("promotional", "notifiable") } do
      patch sign_com_settings_email_url(email.public_id, ri: "jp"),
            params: { visitor_email: { promotional: "0", notifiable: "0" } },
            headers: session_headers
    end

    assert_redirected_to acme_com_settings_email_url(email.public_id, ri: "jp", host: @acme_host)
  end

  test "sign settings email destroy redirects without local account mutation" do
    visitor = create_verified_visitor_with_email(email_address: "sign-com-email-destroy-owner@example.com")
    email = VisitorEmail.create!(
      visitor: visitor,
      address: "sign-com-email-destroy-redirect@example.com",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      confirm_policy: true,
    )

    assert_no_difference("VisitorEmail.count") do
      delete sign_com_settings_email_url(email.public_id, ri: "jp"), headers: session_headers
    end

    assert_redirected_to acme_com_settings_email_url(email.public_id, ri: "jp", host: @acme_host)
    assert_not_predicate email.reload, :destroyed?
  end

  test "sign email registration route remains on sign ceremony surface" do
    get new_sign_com_settings_emails_registration_url(ri: "jp"), headers: session_headers

    assert_equal "sign/com/settings/emails/registrations", @request.path_parameters[:controller]
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
