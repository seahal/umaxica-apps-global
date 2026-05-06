# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Preference::EmailControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
  end

  teardown do
    CloudflareTurnstile.test_mode = nil
    CloudflareTurnstile.test_validation_response = nil
  end

  test "new renders email input form" do
    get new_sign_com_preference_email_url(ri: "jp")

    assert_response :success
  end

  test "create with valid email redirects with success notice" do
    post sign_com_preference_email_url(ri: "jp"),
         params: { preference_email: { email: "test@example.com" } }

    assert_redirected_to new_sign_com_preference_email_url(ri: "jp")
    assert_equal I18n.t("base.com.preference.emails.new.success"), flash[:notice]
  end

  test "create with blank email re-renders new" do
    post sign_com_preference_email_url(ri: "jp"),
         params: { preference_email: { email: "" } }

    assert_response :unprocessable_content
  end

  test "edit with invalid token redirects to new" do
    get edit_sign_com_preference_email_url(ri: "jp", token: "invalid")

    assert_redirected_to new_sign_com_preference_email_url(ri: "jp")
    assert_equal I18n.t("base.shared.preference_emails.token_invalid"), flash[:alert]
  end

  test "update with invalid token redirects to new" do
    patch sign_com_preference_email_url(ri: "jp"),
          params: { preference_email: { token: "invalid", promotional: "1" } }

    assert_redirected_to new_sign_com_preference_email_url(ri: "jp")
  end
end
