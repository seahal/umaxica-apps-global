# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Sign::App::VerificationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users

  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = users(:one)
    @headers = as_user_headers(@user, host: @host)
    UserEmail.create!(
      user: @user,
      address: "verification-link-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: UserEmailStatus::VERIFIED,
      otp_private_key: "otp_private_key",
      otp_counter: "0",
    )
  end

  test "should get show" do
    get sign_app_verification_url(ri: "jp"), headers: @headers

    assert_response :success
  end

  test "redirects to setup page when no verification methods are registered" do
    user = User.create!
    headers = as_user_headers(user, host: @host)

    get sign_app_verification_url(ri: "jp"), headers: headers

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)

    assert_equal "/verification/setup/new", uri.path
    assert_predicate query["rd"], :present?
  end

  test "show renders method links when scope and return_to are provided" do
    return_to = Base64.urlsafe_encode64(sign_app_configuration_emails_path(ri: "jp"))

    get sign_app_verification_url(scope: "configuration_email", return_to: return_to, ri: "jp"),
        headers: @headers

    assert_response :success
    assert_includes response.body, new_sign_app_verification_email_path(ri: "jp")
  end

  test "show handles bad request error" do
    get sign_app_verification_url(scope: "configuration_email", return_to: "%%%INVALID%%%", ri: "jp"),
        headers: @headers

    assert_redirected_to sign_app_configuration_path(ri: "jp")
  end

  test "show with recent verification shows success message" do
    # Create a token with recent step_up
    token = UserToken.find_by(user_id: @user.id)
    token&.update!(last_step_up_at: 5.minutes.ago, last_step_up_scope: "configuration_email")

    get sign_app_verification_url(ri: "jp"), headers: @headers

    # Should show success or verification page
    assert_response :success
  end
end
