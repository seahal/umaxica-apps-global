# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Configuration::SecretsControllerTest < ActionDispatch::IntegrationTest
  fixtures :user_statuses, :user_secret_statuses, :user_secret_kinds, :user_email_statuses

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = User.create!(
      status_id: UserStatus::NOTHING,
      public_id: "secret_user_#{SecureRandom.hex(4)}",
    )
    @token = UserToken.create!(
      user_id: @user.id,
    )
    satisfy_user_verification(@token)
    UserEmail.create!(
      user: @user,
      address: "secret-user@example.com",
      user_email_status_id: UserEmailStatus::VERIFIED,
    )
    @user_secret = UserSecret.create!(
      user: @user,
      name: "Test Secret",
      password_digest: "test_password_digest",
      last_used_at: Time.zone.now,
      user_secret_kind_id: UserSecret::Kinds::LOGIN,
    )
  end

  def authenticated_headers
    headers = browser_headers.merge(
      "X-TEST-CURRENT-USER" => @user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    )

    # browser_headers sets an explicit 'Cookie' header which overwrites the cookie jar.
    # We must manually append our verification cookie if it exists.
    verification_token = cookies[UserVerification.cookie_name]
    if verification_token
      headers["Cookie"] = "#{headers["Cookie"]}; #{UserVerification.cookie_name}=#{verification_token}"
    end

    headers
  end

  test "should get index" do
    get sign_app_configuration_secrets_url(ri: "jp"), headers: authenticated_headers

    assert_response :success
  end

  test "should show back link on index page" do
    get sign_app_configuration_secrets_url(ri: "jp"), headers: authenticated_headers

    assert_response :success
    assert_select "a[href=?]", sign_app_configuration_path(ri: "jp")
  end

  test "should get show" do
    get sign_app_configuration_secret_url(@user_secret, ri: "jp"), headers: authenticated_headers

    assert_response :success
  end

  test "should get new" do
    get new_sign_app_configuration_secret_url(ri: "jp"), headers: authenticated_headers

    assert_response :success
  end

  test "new returns forbidden plain message when user has no verified recovery identity" do
    user = User.create!(status_id: UserStatus::NOTHING, public_id: "u_no_id_#{SecureRandom.hex(4)}")
    token = UserToken.create!(
      user_id: user.id, last_step_up_at: 1.minute.ago,
      last_step_up_scope: "configuration_secret",
    )
    headers = browser_headers.merge(
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    )

    get new_sign_app_configuration_secret_url(ri: "jp"), headers: headers

    assert_response :forbidden
    assert_includes response.body, User::RECOVERY_IDENTITY_REQUIRED_MESSAGE
  end

  test "should show back link on new page" do
    get new_sign_app_configuration_secret_url(ri: "jp"), headers: authenticated_headers

    assert_response :success
    assert_select "a[href=?]", sign_app_configuration_path(ri: "jp"),
                  text: /#{Regexp.escape(I18n.t("actions.back"))}/
  end

  test "should get edit" do
    get edit_sign_app_configuration_secret_url(@user_secret, ri: "jp"), headers: authenticated_headers

    assert_response :success
  end

  test "should show back link on edit page" do
    get edit_sign_app_configuration_secret_url(@user_secret, ri: "jp"), headers: authenticated_headers

    assert_response :success
    assert_select "a[href=?]", sign_app_configuration_path(ri: "jp"),
                  text: /#{Regexp.escape(I18n.t("actions.back"))}/
  end

  test "should create secret and redirect to index" do
    assert_difference("UserSecret.count", 1) do
      post sign_app_configuration_secrets_url(ri: "jp"),
           params: { user_secret: { name: "New Secret", enabled: true } },
           headers: authenticated_headers
    end

    assert_redirected_to sign_app_configuration_secrets_url(ri: "jp")
    assert_predicate flash[:notice], :present?
    assert_nil flash[:raw_secret], "raw secret must not be exposed in flash"
  end

  test "create returns unprocessable entity plain message when user has no verified recovery identity" do
    user = User.create!(status_id: UserStatus::NOTHING, public_id: "u_no_id_c_#{SecureRandom.hex(4)}")
    token = UserToken.create!(
      user_id: user.id, last_step_up_at: 1.minute.ago,
      last_step_up_scope: "configuration_secret",
    )
    headers = browser_headers.merge(
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    )

    assert_no_difference("UserSecret.count") do
      post sign_app_configuration_secrets_url(ri: "jp"),
           params: { user_secret: { name: "Blocked Secret", enabled: true } },
           headers: headers
    end

    assert_response :unprocessable_entity
    assert_includes response.body, User::RECOVERY_IDENTITY_REQUIRED_MESSAGE
  end

  test "update is not routable (secret overwrite is disabled)" do
    patch sign_app_configuration_secret_url(@user_secret, ri: "jp"),
          params: { user_secret: { name: "Updated Secret", enabled: false } },
          headers: authenticated_headers

    assert_response :not_found
    assert_equal "Test Secret", @user_secret.reload.name
  end

  test "should get destroy" do
    satisfy_user_verification(@token)
    delete sign_app_configuration_secret_url(@user_secret, ri: "jp"), headers: authenticated_headers

    assert_response :see_other
    assert_redirected_to sign_app_configuration_secrets_url(ri: "jp")
    assert_predicate flash[:notice], :present?
  end

  test "URL uses public_id not numeric ID" do
    get sign_app_configuration_secret_url(@user_secret, ri: "jp"), headers: authenticated_headers

    assert_response :success
    # Verify URL contains public_id, not numeric ID
    assert_not_includes request.fullpath, "/#{@user_secret.id}/"
    assert_includes request.fullpath, "/#{@user_secret.public_id}"
  end

  test "should access secret by public_id" do
    get sign_app_configuration_secret_url(@user_secret.public_id, ri: "jp"), headers: authenticated_headers

    assert_response :success
    assert_equal @user_secret.public_id, request.path_parameters[:id]
    assert_nil request.path_parameters[:public_id]
  end

  test "should not access secret by numeric ID" do
    get sign_app_configuration_secret_url(@user_secret.id, ri: "jp"), headers: authenticated_headers

    assert_response :not_found
  end

  test "should return 404 for other user's secret" do
    other_user = create_verified_user_with_email(email_address: "other_secret_user@example.com")
    other_secret = UserSecret.create!(
      user: other_user,
      name: "Other Secret",
      password_digest: "test_password_digest",
      user_secret_kind_id: UserSecret::Kinds::LOGIN,
      public_id: "secret_other_#{SecureRandom.hex(4)}",
    )

    get sign_app_configuration_secret_url(other_secret.public_id, ri: "jp"), headers: authenticated_headers

    assert_response :not_found
  end

  test "update route stays unavailable even when secret is last method" do
    user = create_verified_user_with_email(email_address: "update_block_user@example.com")
    token = UserToken.create!(
      user_id: user.id,
    )
    satisfy_user_verification(token)
    secret = UserSecret.create!(
      user: user,
      name: "Only Secret",
      password_digest: "test_password_digest",
      user_secret_kind_id: UserSecret::Kinds::LOGIN,
    )

    patch sign_app_configuration_secret_url(secret, ri: "jp"),
          params: { user_secret: { enabled: false } },
          headers: {
            "Host" => ENV["ID_SERVICE_URL"] || "id.app.localhost",
            "X-TEST-CURRENT-USER" => user.id.to_s,
            "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
          }

    assert_response :not_found
    assert_equal UserSecretStatus::ACTIVE, secret.reload.user_identity_secret_status_id
  end

  test "destroy blocks last method" do
    user = create_verified_user_with_email(email_address: "destroy_block_user@example.com")
    token = UserToken.create!(
      user_id: user.id,
    )
    satisfy_user_verification(token)
    secret = UserSecret.create!(
      user: user,
      name: "Only Secret",
      password_digest: "test_password_digest",
      user_secret_kind_id: UserSecret::Kinds::LOGIN,
    )
    user.user_emails.update_all(user_email_status_id: UserEmailStatus::UNVERIFIED)

    assert_no_difference("UserSecret.count") do
      delete sign_app_configuration_secret_url(secret, ri: "jp"),
             headers: {
               "Host" => ENV["ID_SERVICE_URL"] || "id.app.localhost",
               "X-TEST-CURRENT-USER" => user.id.to_s,
               "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
             }
    end

    assert_redirected_to sign_app_configuration_secrets_url(ri: "jp")
    assert_equal I18n.t("sign.app.configuration.secrets.destroy.last_method"), flash[:alert]
  end
end
