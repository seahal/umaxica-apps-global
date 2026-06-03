# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Settings::EmailsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_email_statuses

  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @acme_host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    host! @host
  end

  test "sign settings emails index redirects to acme authority" do
    get sign_app_settings_emails_url(ri: "jp")

    assert_redirected_to acme_app_settings_emails_url(ri: "jp", host: @acme_host)
  end

  test "sign settings email edit redirects without loading email" do
    get edit_sign_app_settings_email_url("missing", ri: "jp")

    assert_redirected_to edit_acme_app_settings_email_url("missing", ri: "jp", host: @acme_host)
  end

  test "sign settings email update redirects without local preference mutation" do
    email = ClientEmail.create!(
      address: "sign-email-update-redirect@example.com",
      user: clients(:one),
      user_email_status_id: ClientEmailStatus::VERIFIED,
      promotional: true,
      notifiable: true,
    )

    assert_no_changes -> { email.reload.attributes.slice("promotional", "notifiable") } do
      patch sign_app_settings_email_url(email.public_id, ri: "jp"),
            params: { user_email: { promotional: "0", notifiable: "0" } }
    end

    assert_redirected_to acme_app_settings_email_url(email.public_id, ri: "jp", host: @acme_host)
  end

  test "sign settings email destroy redirects without local account mutation" do
    email = ClientEmail.create!(
      address: "sign-email-destroy-redirect@example.com",
      user: clients(:one),
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    assert_no_difference("ClientEmail.count") do
      delete sign_app_settings_email_url(email.public_id, ri: "jp")
    end

    assert_redirected_to acme_app_settings_email_url(email.public_id, ri: "jp", host: @acme_host)
    assert_not_predicate email.reload, :destroyed?
  end

  test "sign email registration route remains on sign ceremony surface" do
    get new_sign_app_settings_emails_registration_url(ri: "jp")

    assert_equal "sign/app/settings/emails/registrations", @request.path_parameters[:controller]
    assert_equal "new", @request.path_parameters[:action]
  end
end
