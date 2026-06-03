# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Settings::EmailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @acme_host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    host! @host
  end

  test "sign settings emails index redirects to acme authority" do
    get sign_com_settings_emails_url(ri: "jp")

    assert_redirected_to acme_com_settings_emails_url(ri: "jp", host: @acme_host)
  end

  test "sign settings email edit redirects without loading email" do
    get edit_sign_com_settings_email_url("missing", ri: "jp")

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
            params: { visitor_email: { promotional: "0", notifiable: "0" } }
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
      delete sign_com_settings_email_url(email.public_id, ri: "jp")
    end

    assert_redirected_to acme_com_settings_email_url(email.public_id, ri: "jp", host: @acme_host)
    assert_not_predicate email.reload, :destroyed?
  end

  test "sign email registration route remains on sign ceremony surface" do
    get new_sign_com_settings_emails_registration_url(ri: "jp")

    assert_equal "sign/com/settings/emails/registrations", @request.path_parameters[:controller]
    assert_equal "new", @request.path_parameters[:action]
  end
end
