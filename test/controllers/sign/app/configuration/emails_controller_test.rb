# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Configuration::EmailsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :user_statuses, :user_token_statuses, :user_token_kinds, :user_email_statuses,
           :user_telephone_statuses, :user_passkey_statuses, :user_chronicle_events, :user_chronicle_levels

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = User.create!(status_id: UserStatus::NOTHING)
    @token = UserToken.create!(
      user_id: @user.id,
    )
    satisfy_user_verification(@token)

    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  def request_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-USER" => @user.id,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end

  def with_prosopite_paused
    Prosopite.pause { yield }
  end

  test "should get index" do
    UserEmail.create!(
      address: "index-email@example.com",
      user: @user,
      user_email_status_id: UserEmailStatus::VERIFIED,
    )

    with_prosopite_paused { get sign_app_configuration_emails_url(ri: "jp"), headers: request_headers }

    assert_response :success
  end

  test "index requires step up when verified email exists" do
    user = User.create!
    token = UserToken.create!(user_id: user.id)
    UserEmail.create!(
      address: "verified-no-step-up@example.com",
      user: user,
      user_email_status_id: UserEmailStatus::VERIFIED,
    )
    headers = {
      "Host" => @host,
      "X-TEST-CURRENT-USER" => user.id,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    with_prosopite_paused { get sign_app_configuration_emails_url(ri: "jp"), headers: headers }

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)

    assert_equal "/verification", uri.path
    assert_equal "configuration_email", query["scope"]
    assert_predicate query["rt"], :present?
  end

  test "edit requires step up when verified email exists" do
    user = User.create!
    token = UserToken.create!(user_id: user.id)
    email = UserEmail.create!(
      address: "verified-edit-step-up@example.com",
      user: user,
      user_email_status_id: UserEmailStatus::VERIFIED,
    )
    headers = {
      "Host" => @host,
      "X-TEST-CURRENT-USER" => user.id,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    with_prosopite_paused { get edit_sign_app_configuration_email_url(email.public_id, ri: "jp"), headers: headers }

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)

    assert_equal "/verification", uri.path
    assert_equal "configuration_email", query["scope"]
    assert_predicate query["rt"], :present?
  end

  test "index shows empty state and registration link when verified email does not exist" do
    user = User.create!
    token = UserToken.create!(user_id: user.id)
    UserEmail.create!(
      address: "unverified-step-up@example.com",
      user: user,
      user_email_status_id: UserEmailStatus::UNVERIFIED,
    )
    headers = {
      "Host" => @host,
      "X-TEST-CURRENT-USER" => user.id,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    with_prosopite_paused { get sign_app_configuration_emails_url(ri: "jp"), headers: headers }

    assert_response :success
    assert_select "a[href=?]", new_sign_app_configuration_emails_registration_path(ri: "jp")
  end

  test "index shows empty state and registration link when no email exists" do
    user = User.create!
    token = UserToken.create!(user_id: user.id)
    headers = {
      "Host" => @host,
      "X-TEST-CURRENT-USER" => user.id,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    with_prosopite_paused { get sign_app_configuration_emails_url(ri: "jp"), headers: headers }

    assert_response :success
    assert_select "a[href=?]", new_sign_app_configuration_emails_registration_path(ri: "jp")
  end

  test "index displays verified status" do
    email = UserEmail.create!(
      address: "verified@example.com",
      user: @user,
      user_email_status_id: UserEmailStatus::VERIFIED,
    )

    with_prosopite_paused { get sign_app_configuration_emails_url(ri: "jp"), headers: request_headers }

    assert_response :success
    assert_includes @response.body, "認証済み"
    assert_includes @response.body, email.address
  end

  test "edit renders delete form with region parameter" do
    email = UserEmail.create!(
      address: "delete-form@example.com",
      user: @user,
      user_email_status_id: UserEmailStatus::VERIFIED,
    )

    with_prosopite_paused {
      get edit_sign_app_configuration_email_url(email.public_id, ri: "jp"), headers: request_headers
    }

    assert_response :success
    assert_select(
      "form[action=?] input[name=?][value=?]",
      sign_app_configuration_email_path(email.public_id, ri: "jp"),
      "_method",
      "delete",
      count: 1,
    )
  end

  test "edit renders email preference toggles with current values" do
    email = UserEmail.create!(
      address: "preference-form@example.com",
      user: @user,
      user_email_status_id: UserEmailStatus::VERIFIED,
      promotional: false,
      notifiable: true,
    )

    with_prosopite_paused {
      get edit_sign_app_configuration_email_url(email.public_id, ri: "jp"), headers: request_headers
    }

    assert_response :success
    assert_select(
      "form[action=?][method=?] input[name=?][value=?]",
      sign_app_configuration_email_path(email.public_id, ri: "jp"),
      "post",
      "_method",
      "patch",
      count: 1,
    )
    assert_select "input[type=checkbox][name='user_email[promotional]'][checked]", count: 0
    assert_select "input[type=checkbox][name='user_email[notifiable]'][checked]", count: 1
    assert_select "input[name='cf-turnstile-response'][type='hidden']", count: 1
    assert_includes response.body, "turnstile.execute"
  end

  test "edit disables email preference toggles when email is unverified" do
    email = UserEmail.create!(
      address: "locked-preference-form@example.com",
      user: @user,
      user_email_status_id: UserEmailStatus::UNVERIFIED,
      promotional: false,
      notifiable: true,
    )

    with_prosopite_paused {
      get edit_sign_app_configuration_email_url(email.public_id, ri: "jp"), headers: request_headers
    }

    assert_response :success
    assert_select "input[type=checkbox][name='user_email[promotional]'][disabled]", count: 1
    assert_select "input[type=checkbox][name='user_email[notifiable]'][disabled]", count: 1
  end

  test "update changes optional email preferences only" do
    email = UserEmail.create!(
      address: "preference-update@example.com",
      user: @user,
      user_email_status_id: UserEmailStatus::VERIFIED,
      promotional: true,
      notifiable: true,
      subscribable: true,
    )

    with_prosopite_paused do
      patch sign_app_configuration_email_url(email.public_id, ri: "jp"),
            params: {
              user_email: {
                promotional: "0",
                notifiable: "0",
                subscribable: "0",
              },
            },
            headers: request_headers
    end

    assert_response :see_other
    assert_redirected_to edit_sign_app_configuration_email_url(email.public_id, ri: "jp")

    email.reload

    assert_not email.promotional
    assert_not email.notifiable
    assert email.subscribable
  end

  test "update keeps email preferences unchanged when email is unverified" do
    email = UserEmail.create!(
      address: "locked-preference-update@example.com",
      user: @user,
      user_email_status_id: UserEmailStatus::UNVERIFIED,
      promotional: true,
      notifiable: true,
      subscribable: true,
    )

    with_prosopite_paused do
      patch sign_app_configuration_email_url(email.public_id, ri: "jp"),
            params: {
              user_email: {
                promotional: "0",
                notifiable: "0",
                subscribable: "0",
              },
            },
            headers: request_headers
    end

    assert_response :see_other
    assert_redirected_to edit_sign_app_configuration_email_url(email.public_id, ri: "jp")

    email.reload

    assert email.promotional
    assert email.notifiable
    assert email.subscribable
  end

  test "update rejects when turnstile fails" do
    email = UserEmail.create!(
      address: "turnstile-failure@example.com",
      user: @user,
      user_email_status_id: UserEmailStatus::VERIFIED,
      promotional: true,
      notifiable: true,
    )
    CloudflareTurnstile.test_validation_response = { "success" => false }

    with_prosopite_paused do
      patch sign_app_configuration_email_url(email.public_id, ri: "jp"),
            params: { user_email: { promotional: "0", notifiable: "0" } },
            headers: request_headers
    end

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("turnstile_error")
    assert email.reload.promotional
    assert email.notifiable
  end

  test "update requires step up when verified email exists" do
    user = User.create!
    token = UserToken.create!(user_id: user.id)
    email = UserEmail.create!(
      address: "verified-update-step-up@example.com",
      user: user,
      user_email_status_id: UserEmailStatus::VERIFIED,
      promotional: true,
    )
    headers = {
      "Host" => @host,
      "X-TEST-CURRENT-USER" => user.id,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    with_prosopite_paused do
      patch sign_app_configuration_email_url(email.public_id, ri: "jp"),
            params: { user_email: { promotional: "0", notifiable: "1" } },
            headers: headers
    end

    assert_response :unauthorized
    assert_equal Verification::Base::REAUTH_REQUIRED_MESSAGE, response.body
    assert email.reload.promotional
  end

  test "update does not change another user's email" do
    other_user = User.create!
    email = UserEmail.create!(
      address: "other-user-preference@example.com",
      user: other_user,
      user_email_status_id: UserEmailStatus::VERIFIED,
      promotional: true,
      notifiable: true,
    )

    assert_no_changes -> { email.reload.attributes.slice("promotional", "notifiable") } do
      with_prosopite_paused do
        patch sign_app_configuration_email_url(email.public_id, ri: "jp"),
              params: { user_email: { promotional: "0", notifiable: "0" } },
              headers: request_headers
      end
    end

    assert_response :not_found
  end

  test "destroy removes email when not last method" do
    email1 = UserEmail.create!(
      address: "delete1@example.com",
      user: @user,
      user_email_status_id: UserEmailStatus::VERIFIED,
    )
    UserEmail.create!(
      address: "delete2@example.com",
      user: @user,
      user_email_status_id: UserEmailStatus::VERIFIED,
    )

    assert_difference("UserEmail.count", -1) do
      assert_difference(
        -> {
          UserChronicle.where(
            actor_type: "User",
            actor_id: @user.id,
            subject_type: "UserEmail",
            subject_id: email1.id,
            event_id: UserChronicleEvent::EMAIL_REMOVED,
          ).count
        },
        1,
      ) do
        with_prosopite_paused { delete sign_app_configuration_email_url(email1, ri: "jp"), headers: request_headers }
      end
    end

    assert_response :see_other
    assert_redirected_to sign_app_configuration_emails_url(ri: "jp")
  end

  test "destroy removes unverified email even when it is not an auth method" do
    email = UserEmail.create!(
      address: "delete-unverified@example.com",
      user: @user,
      user_email_status_id: UserEmailStatus::UNVERIFIED,
    )

    assert_difference("UserEmail.count", -1) do
      with_prosopite_paused { delete sign_app_configuration_email_url(email, ri: "jp"), headers: request_headers }
    end

    assert_response :see_other
    assert_redirected_to sign_app_configuration_emails_url(ri: "jp")
  end

  test "destroy allows removing last email when telephone and passkey are present" do
    user = User.create!(status_id: UserStatus::NOTHING, public_id: "ero_#{SecureRandom.hex(4)}")
    token = UserToken.create!(
      user_id: user.id,
    )
    satisfy_user_verification(token)
    email = UserEmail.create!(
      address: "email_rule_ok@example.com",
      user: user,
      user_email_status_id: UserEmailStatus::VERIFIED,
    )
    UserTelephone.create!(
      number: "+15550001111",
      user: user,
      user_telephone_status_id: UserTelephoneStatus::VERIFIED,
    )
    UserPasskey.create!(
      user: user,
      webauthn_id: "email_rule_ok_pk_#{SecureRandom.hex(6)}",
      public_key: "pk_#{SecureRandom.hex(6)}",
      sign_count: 0,
      description: "pk",
      status_id: UserPasskeyStatus::ACTIVE,
    )

    headers = {
      "Host" => @host,
      "X-TEST-CURRENT-USER" => user.id,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_difference("UserEmail.count", -1) do
      with_prosopite_paused { delete sign_app_configuration_email_url(email, ri: "jp"), headers: headers }
    end

    assert_response :see_other
  end

  test "destroy blocks removing last email when telephone exists but no passkey or social" do
    user = User.create!(status_id: UserStatus::NOTHING, public_id: "ern_#{SecureRandom.hex(4)}")
    token = UserToken.create!(
      user_id: user.id,
    )
    satisfy_user_verification(token)
    email = UserEmail.create!(
      address: "email_rule_ng@example.com",
      user: user,
      user_email_status_id: UserEmailStatus::VERIFIED,
    )
    UserTelephone.create!(
      number: "+15550001112",
      user: user,
      user_telephone_status_id: UserTelephoneStatus::VERIFIED,
    )

    headers = {
      "Host" => @host,
      "X-TEST-CURRENT-USER" => user.id,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_no_difference("UserEmail.count") do
      with_prosopite_paused { delete sign_app_configuration_email_url(email, ri: "jp"), headers: headers }
    end

    assert_redirected_to sign_app_configuration_emails_url(ri: "jp")
    assert_equal I18n.t("sign.app.configuration.email.destroy.last_method"), flash[:alert]
  end

  test "destroy blocks removing an undeletable email" do
    email = UserEmail.create!(
      address: "protected@example.com",
      user: @user,
      user_email_status_id: UserEmailStatus::VERIFIED,
      undeletable: true,
    )
    UserEmail.create!(
      address: "other@example.com",
      user: @user,
      user_email_status_id: UserEmailStatus::VERIFIED,
    )

    assert_no_difference("UserEmail.count") do
      with_prosopite_paused { delete sign_app_configuration_email_url(email, ri: "jp"), headers: request_headers }
    end

    assert_redirected_to sign_app_configuration_emails_url(ri: "jp")
    assert_equal I18n.t("sign.app.configuration.email.destroy.protected"), flash[:alert]
  end
end
