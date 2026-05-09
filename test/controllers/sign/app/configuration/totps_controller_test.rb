# typed: false
# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class Sign::App::Configuration::TotpsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users,
           :user_statuses,
           :user_token_statuses,
           :user_token_kinds,
           :user_one_time_password_statuses,
           :app_preference_chronicle_levels

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = users(:one)
    # Clear existing TOTPs to avoid limit error
    @user.user_one_time_passwords.destroy_all
    UserEmail.create!(
      user: @user,
      address: "totp-config-test@example.com",
      user_email_status_id: UserEmailStatus::VERIFIED,
    )

    @token = UserToken.create!(user_id: @user.id)
    @token.rotate_refresh_token!
    @token.update!(last_step_up_at: 5.minutes.ago, last_step_up_scope: "manage_totp")
    access_token = Authentication::Base::Token.encode(
      @user,
      host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
      session_public_id: @token.public_id,
    )
    @headers = {
      "Host" => ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
      "Authorization" => "Bearer #{access_token}",
    }.freeze
    cookies["csrf_token"] = "test_csrf_token"
    cookies[Authentication::Base::ACCESS_COOKIE_KEY] = access_token
    satisfy_user_verification(@token)
    @headers.freeze

    @totp = UserOneTimePassword.create!(
      user: @user,
      private_key: ROTP::Base32.random_base32,
      last_otp_at: Time.zone.at(0),
      title: "Main TOTP",
      user_one_time_password_status_id: UserOneTimePasswordStatus::ACTIVE,
    )
  end

  test "should get index" do
    get sign_app_configuration_totps_url(ri: "jp"), headers: @headers

    assert_response :success
  end

  test "should show up link on index page" do
    get sign_app_configuration_totps_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_select "a[href=?]", sign_app_configuration_path(ri: "jp")
  end

  test "should get new" do
    get new_sign_app_configuration_totp_url(ri: "jp"), headers: @headers

    assert_response :success
  end

  test "should get edit with public_id" do
    get edit_sign_app_configuration_totp_url(@totp.public_id, ri: "jp"), headers: @headers

    assert_response :success
    assert_equal @totp.public_id, request.path_parameters[:id]
    assert_nil request.path_parameters[:public_id]
  end

  test "should update title with public_id" do
    patch sign_app_configuration_totp_url(@totp.public_id, ri: "jp"),
          params: { user_one_time_password: { title: "Updated TOTP" } },
          headers: @headers

    assert_redirected_to sign_app_configuration_totps_url(ri: "jp")
    assert_equal "Updated TOTP", @totp.reload.title
  end

  test "should destroy with public_id" do
    assert_difference("UserOneTimePassword.count", -1) do
      delete sign_app_configuration_totp_url(@totp.public_id, ri: "jp"), headers: @headers
    end

    assert_redirected_to sign_app_configuration_totps_url(ri: "jp")
  end

  test "should return 404 for other user's totp" do
    other_user = users(:two)
    other_totp = UserOneTimePassword.create!(
      user: other_user,
      private_key: ROTP::Base32.random_base32,
      last_otp_at: Time.zone.at(0),
      title: "Other TOTP",
      user_one_time_password_status_id: UserOneTimePasswordStatus::ACTIVE,
    )

    get edit_sign_app_configuration_totp_url(other_totp.public_id, ri: "jp"), headers: @headers

    assert_response :not_found
  end

  test "should create totp with valid token" do
    # Clear TOTP created in setup to allow creation of a new one (limit is 2)
    @user.user_one_time_passwords.destroy_all

    with_mocked_totp do |secret|
      get new_sign_app_configuration_totp_url(ri: "jp"), headers: @headers

      assert_response :success
      token = ROTP::TOTP.new(secret).now

      assert_difference("UserOneTimePassword.count") do
        post sign_app_configuration_totps_url(ri: "jp"),
             params: { user_one_time_password: { first_token: token } },
             headers: @headers
      end

      assert_redirected_to sign_app_configuration_totps_url(ri: "jp")
    end
  end

  test "should assign attributes to created totp" do
    @user.user_one_time_passwords.destroy_all

    with_mocked_totp do |secret|
      get new_sign_app_configuration_totp_url(ri: "jp"), headers: @headers

      assert_response :success
      token = ROTP::TOTP.new(secret).now

      post sign_app_configuration_totps_url(ri: "jp"),
           params: { user_one_time_password: { first_token: token, title: "New TOTP" } },
           headers: @headers

      created_totp = UserOneTimePassword.order(created_at: :desc).first

      assert_equal @user, created_totp.user
      assert_equal "New TOTP", created_totp.title
      assert_not_nil created_totp.last_otp_at
    end
  end

  test "should not create totp with invalid token" do
    get new_sign_app_configuration_totp_url(ri: "jp"), headers: @headers

    assert_response :success

    assert_no_difference("UserOneTimePassword.count") do
      post sign_app_configuration_totps_url(ri: "jp"),
           params: { user_one_time_password: { first_token: "000000" } },
           headers: @headers
    end

    assert_response :unprocessable_content
  end

  test "initial setup user can access totp pages without step-up" do
    user = create_verified_user_with_email(email_address: "initial_totp_access@example.com")
    token = UserToken.create!(user_id: user.id)
    token.rotate_refresh_token!
    token.update!(last_step_up_at: 5.minutes.ago, last_step_up_scope: "manage_totp")
    satisfy_user_verification(token)
    access_token = Authentication::Base::Token.encode(
      user,
      host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
      session_public_id: token.public_id,
    )
    headers = {
      "Host" => ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
      "Authorization" => "Bearer #{access_token}",
    }
    cookies["csrf_token"] = "test_csrf_token"
    cookies[Authentication::Base::ACCESS_COOKIE_KEY] = access_token
    satisfy_user_verification(token)

    get sign_app_configuration_totps_url(ri: "jp"), headers: headers

    assert_response :success
  end

  test "initial setup user can create first totp without step-up" do
    user = create_verified_user_with_email(email_address: "initial_totp_create@example.com")
    token = UserToken.create!(user_id: user.id)
    token.rotate_refresh_token!
    token.update!(last_step_up_at: 5.minutes.ago, last_step_up_scope: "manage_totp")
    satisfy_user_verification(token)
    access_token = Authentication::Base::Token.encode(
      user,
      host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
      session_public_id: token.public_id,
    )
    headers = {
      "Host" => ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
      "Authorization" => "Bearer #{access_token}",
    }
    cookies["csrf_token"] = "test_csrf_token"
    cookies[Authentication::Base::ACCESS_COOKIE_KEY] = access_token
    satisfy_user_verification(token)

    with_mocked_totp do |secret|
      get new_sign_app_configuration_totp_url(ri: "jp"), headers: headers

      assert_response :success
      first_code = ROTP::TOTP.new(secret).now

      assert_difference("UserOneTimePassword.count", 1) do
        post sign_app_configuration_totps_url(ri: "jp"),
             params: { user_one_time_password: { first_token: first_code } },
             headers: headers
      end
    end

    assert_redirected_to sign_app_configuration_totps_url(ri: "jp")
  end

  private

  def with_mocked_totp
    known_secret = "JBSWY3DPEHPK3PXP"
    ROTP::Base32.stub(:random_base32, known_secret) do
      yield known_secret
    end
  end
end
