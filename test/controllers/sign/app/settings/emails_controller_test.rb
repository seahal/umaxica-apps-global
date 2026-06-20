# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Settings::EmailsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_email_statuses, :client_token_kinds

  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @acme_host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    @user = clients(:one)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    mark_token_step_up_satisfied_for_test(@token, scope: "settings_email")
    host! @host
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "sign settings emails index renders email list" do
    get sign_app_settings_emails_url(ri: "jp"), headers: session_headers

    assert_response :ok
  end

  test "sign settings email edit renders form" do
    email = ClientEmail.create!(
      address: "sign-email-edit-form@example.com",
      user: clients(:one),
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    get edit_sign_app_settings_email_url(email.public_id, ri: "jp"), headers: session_headers

    assert_response :ok
  end

  test "sign settings email update mutates preferences on sign surface" do
    email = ClientEmail.create!(
      address: "sign-email-update-redirect@example.com",
      user: clients(:one),
      user_email_status_id: ClientEmailStatus::VERIFIED,
      promotional: true,
      notifiable: true,
    )

    patch sign_app_settings_email_url(email.public_id, ri: "jp"),
          params: { user_email: { promotional: "0", notifiable: "0" } },
          headers: session_headers

    assert_redirected_to edit_sign_app_settings_email_path(email.public_id, ri: "jp")
    assert_not email.reload.promotional
    assert_not email.reload.notifiable
  end

  test "sign settings email destroy removes unverified email" do
    email = ClientEmail.create!(
      address: "sign-email-destroy-redirect@example.com",
      user: clients(:one),
      user_email_status_id: ClientEmailStatus::UNVERIFIED,
    )

    assert_difference("ClientEmail.count", -1) do
      delete sign_app_settings_email_url(email.public_id, ri: "jp"), headers: session_headers
    end

    assert_redirected_to sign_app_settings_emails_path(ri: "jp")
  end

  test "sign email registration route remains on sign ceremony surface" do
    get new_sign_app_settings_emails_registration_url(ri: "jp"), headers: session_headers

    assert_equal "sign/app/settings/emails/registrations", @request.path_parameters[:controller]
    assert_equal "new", @request.path_parameters[:action]
  end

  private

  def session_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-USER" => @user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end
end
