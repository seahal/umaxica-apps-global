# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Preference::EmailControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
  end

  teardown do
    CloudflareTurnstile.test_mode = nil
    CloudflareTurnstile.test_validation_response = nil
  end

  test "new renders email input form" do
    get new_sign_app_preference_email_url(ri: "jp")

    assert_response :success
  end

  test "create with valid email redirects with success notice" do
    post sign_app_preference_email_url(ri: "jp"),
         params: { preference_email: { email: "test@example.com" } }

    assert_redirected_to new_sign_app_preference_email_url(ri: "jp")
    assert_equal I18n.t("base.app.preference.emails.new.success"), flash[:notice]
  end

  test "create with blank email re-renders new" do
    post sign_app_preference_email_url(ri: "jp"),
         params: { preference_email: { email: "" } }

    assert_response :unprocessable_content
  end

  test "edit with invalid token redirects to new" do
    get edit_sign_app_preference_email_url(ri: "jp", token: "invalid")

    assert_redirected_to new_sign_app_preference_email_url(ri: "jp")
    assert_equal I18n.t("base.shared.preference_emails.token_invalid"), flash[:alert]
  end

  test "update with invalid token redirects to new" do
    patch sign_app_preference_email_url(ri: "jp"),
          params: { preference_email: { token: "invalid", promotional: "1" } }

    assert_redirected_to new_sign_app_preference_email_url(ri: "jp")
  end

  test "edit with valid token renders form" do
    user = users(:one)
    email_record = UserEmail.create!(user: user, address: "valid@example.com")
    token = Sign::Preference::EmailToken.issue(
      email_record_id: email_record.id,
      email_record_type: "UserEmail",
      audience: "app",
    )

    get edit_sign_app_preference_email_url(ri: "jp", token: token)

    assert_response :success
    assert_select "input[type=hidden][name='preference_email[token]'][value='#{token}']"
  end

  test "update with valid token updates preferences" do
    user = users(:one)
    email_record = UserEmail.create!(user: user, address: "valid2@example.com", promotional: true)
    token = Sign::Preference::EmailToken.issue(
      email_record_id: email_record.id,
      email_record_type: "UserEmail",
      audience: "app",
    )

    patch sign_app_preference_email_url(ri: "jp"),
          params: { token: token, preference_email: { promotional: "0", subscribable: "1", notifiable: "1" } }

    assert_redirected_to new_sign_app_preference_email_url(ri: "jp")
    assert_equal I18n.t("base.app.preference.emails.edit.submit"), flash[:notice]
    email_record.reload

    assert_not email_record.promotional
  end

  test "unsubscribe with valid token unsubscribes user" do
    user = users(:one)
    email_record = UserEmail.create!(user: user, address: "valid3@example.com", promotional: true, subscribable: true)
    token = Sign::Preference::EmailToken.issue(
      email_record_id: email_record.id,
      email_record_type: "UserEmail",
      audience: "app",
    )

    post unsubscribe_sign_app_preference_email_url(ri: "jp"),
         params: { token: token }

    assert_redirected_to new_sign_app_preference_email_url(ri: "jp")
    assert_equal I18n.t("base.app.preference.emails.edit.submit"), flash[:notice]
    email_record.reload

    assert_not email_record.promotional
    assert_not email_record.subscribable
  end
end
