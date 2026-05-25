# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Sign::App::Configuration::SecretsControllerTest < ActionDispatch::IntegrationTest
  fixtures :client_statuses, :client_secret_statuses, :client_secret_kinds, :client_email_statuses,
           :client_chronicle_events, :client_chronicle_levels

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = Client.create!(
      status_id: ClientStatus::NOTHING,
      public_id: "secret_user_#{SecureRandom.hex(4)}",
    )
    @token = ClientToken.create!(
      user_id: @user.id,
    )
    satisfy_user_verification(@token)
    @token.update!(last_step_up_at: Time.current, last_step_up_scope: "configuration_secret")
    ClientEmail.create!(
      user: @user,
      address: "secret-user@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    @user_secret = ClientSecret.create!(
      user: @user,
      name: "Test Secret",
      password_digest: "test_password_digest",
      last_used_at: Time.zone.now,
      user_secret_kind_id: ClientSecret::Kinds::LOGIN,
    )
    CloudflareTurnstile.validation_override_enabled = true
    CloudflareTurnstile.validation_override_response = { "success" => true }
  end

  teardown do
    CloudflareTurnstile.validation_override_enabled = false
    CloudflareTurnstile.validation_override_response = nil
  end

  def authenticated_headers
    headers = browser_headers.merge(
      "X-TEST-CURRENT-USER" => @user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    )

    # browser_headers sets an explicit 'Cookie' header which overwrites the cookie jar.
    # We must manually append our verification cookie if it exists.
    csrf_token = cookies["csrf_token"]
    verification_token = cookies[ClientVerification.cookie_name]
    if verification_token
      headers["Cookie"] =
        [
          headers["Cookie"],
          ("csrf_token=#{csrf_token}" if csrf_token.present?),
          "#{ClientVerification.cookie_name}=#{verification_token}",
        ]
          .compact_blank
          .join("; ")
    end

    headers
  end

  def with_prosopite_paused
    Prosopite.pause { yield }
  end

  test "should get index" do
    with_prosopite_paused do
      get sign_app_configuration_secrets_url(ri: "jp"), headers: authenticated_headers
    end

    assert_response :success
  end

  test "index requires step-up when session freshness is stale" do
    @token.update!(created_at: 1.hour.ago, last_step_up_at: nil, last_step_up_scope: nil)
    cookies.delete(ClientVerification.cookie_name)

    with_prosopite_paused do
      get sign_app_configuration_secrets_url(ri: "jp"), headers: authenticated_headers
    end

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)

    assert_equal "/verification", uri.path
    assert_equal "configuration_secret", query["scope"]
    assert_predicate query["rt"], :present?
    assert_match(/--/, query["rt"])
  end

  test "should show back link on index page" do
    with_prosopite_paused do
      get sign_app_configuration_secrets_url(ri: "jp"), headers: authenticated_headers
    end

    assert_response :success
    assert_select "a[href=?]", sign_app_configuration_path(ri: "jp")
  end

  test "index renders destroy as delete form" do
    with_prosopite_paused do
      get sign_app_configuration_secrets_url(ri: "jp"), headers: authenticated_headers
    end

    assert_response :success
    assert_select "form[action=?][method=?]",
                  sign_app_configuration_secret_path(@user_secret, ri: "jp"),
                  "post" do
      assert_select "input[name=?][value=?]", "_method", "delete"
    end
  end

  test "should get show" do
    with_prosopite_paused do
      get sign_app_configuration_secret_url(@user_secret, ri: "jp"), headers: authenticated_headers
    end

    assert_response :success
  end

  test "new redirects to setup when MFA is unavailable" do
    user = Client.create!(status_id: ClientStatus::NOTHING, public_id: "u_no_mfa_#{SecureRandom.hex(4)}")
    token = ClientToken.create!(user_id: user.id)
    token.update!(created_at: 1.hour.ago)
    headers = browser_headers.merge(
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    )

    with_prosopite_paused do
      get new_sign_app_configuration_secret_url(ri: "jp"), headers: headers
    end

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)

    assert_equal "/verification/setup/new", uri.path
    assert_equal "jp", query["ri"]
    assert_predicate query["rt"], :present?
    assert_match(/--/, query["rt"])
  end

  test "new returns forbidden plain message when user has no verified recovery identity" do
    user = Client.create!(status_id: ClientStatus::NOTHING, public_id: "u_no_id_#{SecureRandom.hex(4)}")
    token = ClientToken.create!(
      user_id: user.id, last_step_up_at: 1.minute.ago,
      last_step_up_scope: "configuration_secret",
    )
    headers = browser_headers.merge(
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    )

    with_prosopite_paused do
      get new_sign_app_configuration_secret_url(ri: "jp"), headers: headers
    end

    assert_response :forbidden
    assert_includes response.body, Client::RECOVERY_IDENTITY_REQUIRED_MESSAGE
  end

  test "should show back link on new page" do
    @token.update!(last_step_up_at: Time.current, last_step_up_scope: "configuration_secret")

    with_prosopite_paused do
      get new_sign_app_configuration_secret_url(ri: "jp"), headers: authenticated_headers
    end

    assert_response :success
    assert_select "a[href=?]", sign_app_configuration_path(ri: "jp"),
                  text: /#{Regexp.escape(I18n.t("actions.back"))}/
  end

  test "should get edit" do
    with_prosopite_paused do
      get edit_sign_app_configuration_secret_url(@user_secret, ri: "jp"), headers: authenticated_headers
    end

    assert_response :success
  end

  test "should show back link on edit page" do
    with_prosopite_paused do
      get edit_sign_app_configuration_secret_url(@user_secret, ri: "jp"), headers: authenticated_headers
    end

    assert_response :success
    assert_select "a[href=?]", sign_app_configuration_path(ri: "jp"),
                  text: /#{Regexp.escape(I18n.t("actions.back"))}/
  end

  test "should create secret and redirect to index" do
    @token.update!(last_step_up_at: Time.current, last_step_up_scope: "configuration_secret")
    step_up_before = Time.current

    assert_difference("ClientSecret.count", 1) do
      assert_difference(
        -> {
          ClientChronicle.where(
            actor_type: "Client",
            actor_id: @user.id,
            event_id: ClientChronicleEvent::USER_SECRET_CREATED,
          ).count
        },
        1,
      ) do
        with_prosopite_paused do
          post sign_app_configuration_secrets_url(ri: "jp"),
               params: { user_secret: { name: "New Secret", enabled: true }, "cf-turnstile-response": "test" },
               headers: authenticated_headers
        end
      end
    end

    assert_redirected_to sign_app_configuration_secrets_url(ri: "jp")
    assert_predicate flash[:notice], :present?
    assert_nil flash[:raw_secret], "raw secret must not be exposed in flash"
    assert_operator @token.reload.last_step_up_at, :>=, step_up_before
    assert_equal "configuration_secret", @token.last_step_up_scope
  end

  test "create redirects to setup when MFA is unavailable" do
    user = Client.create!(status_id: ClientStatus::NOTHING, public_id: "u_no_mfa_c_#{SecureRandom.hex(4)}")
    token = ClientToken.create!(user_id: user.id)
    token.update!(created_at: 1.hour.ago)
    headers = browser_headers.merge(
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    )

    assert_no_difference("ClientSecret.count") do
      with_prosopite_paused do
        post sign_app_configuration_secrets_url(ri: "jp"),
             params: { user_secret: { name: "Blocked Secret", enabled: true }, "cf-turnstile-response": "test" },
             headers: headers
      end
    end

    assert_response :see_other
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)

    assert_equal "/verification/setup/new", uri.path
    assert_equal "jp", query["ri"]
    assert_predicate query["rt"], :present?
    assert_match(/--/, query["rt"])
  end

  test "create returns unprocessable entity plain message when user has no verified recovery identity" do
    user = Client.create!(status_id: ClientStatus::NOTHING, public_id: "u_no_id_c_#{SecureRandom.hex(4)}")
    token = ClientToken.create!(
      user_id: user.id, last_step_up_at: 1.minute.ago,
      last_step_up_scope: "configuration_secret",
    )
    headers = browser_headers.merge(
      "X-TEST-CURRENT-USER" => user.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    )

    assert_no_difference("ClientSecret.count") do
      with_prosopite_paused do
        post sign_app_configuration_secrets_url(ri: "jp"),
             params: { user_secret: { name: "Blocked Secret", enabled: true }, "cf-turnstile-response": "test" },
             headers: headers
      end
    end

    assert_response :unprocessable_entity
    assert_includes response.body, Client::RECOVERY_IDENTITY_REQUIRED_MESSAGE
  end

  test "should update secret name and status" do
    assert_difference(
      -> {
        ClientChronicle.where(
          actor_type: "Client",
          actor_id: @user.id,
          event_id: ClientChronicleEvent::USER_SECRET_UPDATED,
        ).count
      },
      1,
    ) do
      with_prosopite_paused do
        patch sign_app_configuration_secret_url(@user_secret, ri: "jp"),
              params: { user_secret: { name: "Updated Secret", enabled: false } },
              headers: authenticated_headers
      end
    end

    assert_redirected_to sign_app_configuration_secrets_url(ri: "jp")
    @user_secret.reload

    assert_equal "Updated Secret", @user_secret.name
    assert_equal ClientSecretStatus::REVOKED, @user_secret.user_identity_secret_status_id
  end

  test "should get destroy" do
    satisfy_user_verification(@token)
    @token.update!(last_step_up_at: Time.current, last_step_up_scope: "configuration_secret")
    AuthMethodGuard.stub(:last_method?, false) do
      with_prosopite_paused do
        delete sign_app_configuration_secret_url(@user_secret, ri: "jp"), headers: authenticated_headers
      end
    end

    assert_response :see_other
    assert_redirected_to sign_app_configuration_secrets_url(ri: "jp")
    assert_predicate flash[:notice], :present?
  end

  test "URL uses public_id not numeric ID" do
    with_prosopite_paused do
      get sign_app_configuration_secret_url(@user_secret, ri: "jp"), headers: authenticated_headers
    end

    assert_response :success
    # Verify URL contains public_id, not numeric ID
    assert_not_includes request.fullpath, "/#{@user_secret.id}/"
    assert_includes request.fullpath, "/#{@user_secret.public_id}"
  end

  test "should access secret by public_id" do
    with_prosopite_paused do
      get sign_app_configuration_secret_url(@user_secret.public_id, ri: "jp"), headers: authenticated_headers
    end

    assert_response :success
    assert_equal @user_secret.public_id, request.path_parameters[:id]
    assert_nil request.path_parameters[:public_id]
  end

  test "should not access secret by numeric ID" do
    with_prosopite_paused do
      get sign_app_configuration_secret_url(@user_secret.id, ri: "jp"), headers: authenticated_headers
    end

    assert_response :not_found
  end

  test "should return 404 for other user's secret" do
    other_user = create_verified_user_with_email(email_address: "other_secret_user@example.com")
    other_secret = ClientSecret.create!(
      user: other_user,
      name: "Other Secret",
      password_digest: "test_password_digest",
      user_secret_kind_id: ClientSecret::Kinds::LOGIN,
      public_id: "secret_other_#{SecureRandom.hex(4)}",
    )

    with_prosopite_paused do
      get sign_app_configuration_secret_url(other_secret.public_id, ri: "jp"), headers: authenticated_headers
    end

    assert_response :not_found
  end

  test "update does not disable last method" do
    user = create_verified_user_with_email(email_address: "update_block_user@example.com")
    token = ClientToken.create!(
      id: ClientToken.maximum(:id).to_i + 1,
      user_id: user.id,
    )
    satisfy_user_verification(token)
    token.update!(last_step_up_at: Time.current, last_step_up_scope: "configuration_secret")
    secret = ClientSecret.create!(
      user: user,
      name: "Only Secret",
      password_digest: "test_password_digest",
      user_secret_kind_id: ClientSecret::Kinds::LOGIN,
    )

    AuthMethodGuard.stub(:last_method?, true) do
      with_prosopite_paused do
        patch sign_app_configuration_secret_url(secret, ri: "jp"),
              params: { user_secret: { enabled: false }, "cf-turnstile-response": "test" },
              headers: {
                "Host" => ENV["ID_SERVICE_URL"] || "id.app.localhost",
                "X-TEST-CURRENT-USER" => user.id.to_s,
                "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
              }
      end
    end

    assert_redirected_to sign_app_configuration_secrets_url(ri: "jp")
    assert_predicate flash[:alert], :present?
    assert_equal ClientSecretStatus::ACTIVE, secret.reload.user_identity_secret_status_id
  end

  test "create requires successful stealth turnstile" do
    CloudflareTurnstile.validation_override_response = { "success" => false }

    assert_no_difference("ClientSecret.count") do
      with_prosopite_paused do
        post sign_app_configuration_secrets_url(ri: "jp"),
             params: { user_secret: { name: "Blocked Secret", enabled: true }, "cf-turnstile-response": "bad" },
             headers: authenticated_headers
      end
    end

    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("turnstile_error")
  end

  test "update requires successful stealth turnstile" do
    CloudflareTurnstile.validation_override_response = { "success" => false }

    with_prosopite_paused do
      patch sign_app_configuration_secret_url(@user_secret, ri: "jp"),
            params: { user_secret: { name: "Blocked Update", enabled: true }, "cf-turnstile-response": "bad" },
            headers: authenticated_headers
    end

    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("turnstile_error")
    assert_equal "Test Secret", @user_secret.reload.name
  end

  test "destroy requires successful stealth turnstile" do
    CloudflareTurnstile.validation_override_response = { "success" => false }

    assert_no_difference("ClientSecret.where.not(user_identity_secret_status_id: ClientSecretStatus::DELETED).count") do
      with_prosopite_paused do
        delete sign_app_configuration_secret_url(@user_secret, ri: "jp"),
               params: { "cf-turnstile-response": "bad" },
               headers: authenticated_headers
      end
    end

    assert_response :see_other
    assert_redirected_to sign_app_configuration_secrets_url(ri: "jp")
    assert_predicate flash[:alert], :present?
  end
end
