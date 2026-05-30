# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Configuration::Telephones::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_telephone_statuses, :client_chronicle_events, :client_chronicle_levels
  include ActiveJob::TestHelper

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = clients(:one)
    @token = ClientToken.create!(
      user_id: @user.id,
    )
    satisfy_user_verification(@token)
    @token.update!(last_step_up_at: Time.current, last_step_up_scope: "configuration_telephone")

    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  def request_headers
    access_token = Authentication::TokenService.encode(
      @user,
      host: @host,
      session_public_id: @token.public_id,
      resource_type: "client",
      expires_at: 1.hour.from_now,
      acr: "aal1",
      amr: ["test"],
    )

    {
      "Host" => @host,
      "Authorization" => "Bearer #{access_token}",
      "X-TEST-CURRENT-USER" => @user.id,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end

  test "create registers telephone for current user without signup confirmation params" do
    assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
      assert_difference("ClientTelephone.count", 1) do
        post sign_app_configuration_telephones_registration_url(ri: "jp"),
             params: { user_telephone: { raw_number: "+10000000009" } },
             headers: request_headers
      end
    end

    assert_response :redirect
    assert_redirected_to edit_sign_app_configuration_telephones_registration_url(ri: "jp")

    user_telephone = ClientTelephone.order(created_at: :desc).first

    assert_equal @user.id, user_telephone.user_id
    assert_equal ClientTelephoneStatus::UNVERIFIED, user_telephone.user_telephone_status_id
    assert_equal 0, ClientTelephone.where(user_id: 0).count
    job = enqueued_jobs.last

    assert_equal Outbound::SmsDeliveryJob, job[:job]
    assert_equal "+10000000009", job[:args].first["to"]
  end

  test "create returns 422 for invalid number" do
    assert_no_difference("ClientTelephone.count") do
      post sign_app_configuration_telephones_registration_url(ri: "jp"),
           params: { user_telephone: { raw_number: "invalid-number" } },
           headers: request_headers
    end

    assert_response :unprocessable_content
  end

  test "create reuses existing telephone and sends sms when same number is submitted again" do
    existing = ClientTelephone.create!(
      number: "+10000000011",
      user: @user,
      user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )

    assert_enqueued_jobs 1, only: Outbound::SmsDeliveryJob do
      assert_no_difference("ClientTelephone.count") do
        post sign_app_configuration_telephones_registration_url(ri: "jp"),
             params: { user_telephone: { raw_number: "+10000000011" } },
             headers: request_headers
      end
    end

    assert_response :redirect
    assert_redirected_to edit_sign_app_configuration_telephones_registration_url(ri: "jp")

    reused = ClientTelephone.find(existing.id)

    assert_equal ClientTelephoneStatus::UNVERIFIED, reused.user_telephone_status_id
  end
  test "new renders successfully and resets session" do
    get new_sign_app_configuration_telephones_registration_url(ri: "jp"),
        headers: request_headers

    assert_response :success
    assert_select "input[name='cf-turnstile-response'][type='hidden']", count: 1
    assert_includes response.body, 'data-turnstile-mode-value="execute"'
  end

  test "create rejects when turnstile fails" do
    CloudflareTurnstile.test_validation_response = { "success" => false }

    assert_no_difference("ClientTelephone.count") do
      post sign_app_configuration_telephones_registration_url(ri: "jp"),
           params: { user_telephone: { raw_number: "+10000000009" } },
           headers: request_headers
    end

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("turnstile_error")
  end

  test "edit redirects if no valid session" do
    get edit_sign_app_configuration_telephones_registration_url(ri: "jp"),
        headers: request_headers

    assert_response :redirect

    assert_redirected_to new_sign_app_configuration_telephones_registration_url(ri: "jp")
    assert_equal I18n.t("sign.app.registration.telephone.edit.session_expired"), flash[:notice]
  end

  test "edit renders if valid session" do
    tel = ClientTelephone.create!(
      user: @user,
      raw_number: "+19999999999",
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED,
      otp_private_key: "secret_credential",
      otp_expires_at: 10.minutes.from_now,
    )
    set_registration_session(tel.id) do
      get edit_sign_app_configuration_telephones_registration_url(ri: "jp"),
          headers: request_headers

      assert_response :success
      assert_select "input[name='cf-turnstile-response'][type='hidden']", count: 1
      assert_includes response.body, 'data-turnstile-mode-value="execute"'
    end
  end

  test "update redirects if no valid session" do
    patch sign_app_configuration_telephones_registration_url(ri: "jp"),
          params: { user_telephone: { pass_code: "123456" } },
          headers: request_headers

    assert_redirected_to new_sign_app_configuration_telephones_registration_url(ri: "jp")
    assert_equal I18n.t("sign.app.registration.telephone.edit.session_expired"), flash[:notice]
  end

  test "update renders unprocessable if code is blank" do
    tel = ClientTelephone.create!(
      user: @user,
      raw_number: "+19999999999",
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED,
      otp_private_key: "secret_credential",
      otp_expires_at: 10.minutes.from_now,
    )
    set_registration_session(tel.id) do
      patch sign_app_configuration_telephones_registration_url(ri: "jp"),
            params: { user_telephone: { pass_code: "" } },
            headers: request_headers

      assert_response :unprocessable_content
    end
  end

  test "update rejects when turnstile fails" do
    tel = ClientTelephone.create!(
      user: @user,
      raw_number: "+19999999998",
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED,
      otp_private_key: "secret_credential",
      otp_expires_at: 10.minutes.from_now,
    )
    CloudflareTurnstile.test_validation_response = { "success" => false }

    set_registration_session(tel.id) do
      patch sign_app_configuration_telephones_registration_url(ri: "jp"),
            params: { user_telephone: { pass_code: "123456" } },
            headers: request_headers

      assert_response :unprocessable_content
      assert_includes response.body, I18n.t("turnstile_error")
      assert_equal ClientTelephoneStatus::UNVERIFIED, tel.reload.user_telephone_status_id
    end
  end

  test "update successfully verifies telephone" do
    tel = ClientTelephone.create!(
      user: @user,
      raw_number: "+19999999999",
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED,
      otp_private_key: "secret_credential",
      otp_expires_at: 10.minutes.from_now,
    )
    set_registration_session(tel.id) do
      with_complete_telephone_verification(:success, tel) do
        assert_difference(
          -> {
            ClientChronicle.where(
              actor_type: "Client",
              actor_id: @user.id,
              subject_type: "Client",
              subject_id: @user.id,
              event_id: ClientChronicleEvent::TELEPHONE_REGISTERED,
            ).count
          },
          1,
        ) do
          patch sign_app_configuration_telephones_registration_url(ri: "jp"),
                params: { user_telephone: { pass_code: "123456" } },
                headers: request_headers
        end

        assert_redirected_to sign_app_configuration_telephones_url(ri: "jp")
        assert_equal I18n.t("sign.app.registration.telephone.update.success"), flash[:notice]
        assert_not_nil @token.reload.last_step_up_at
        assert_equal "configuration_telephone", @token.last_step_up_scope
      end
    end
  end

  test "telephone registration satisfies telephone configuration step-up" do
    tel = ClientTelephone.create!(
      user: @user,
      raw_number: "+18888888888",
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED,
      otp_private_key: "secret_credential",
      otp_expires_at: 10.minutes.from_now,
    )

    set_registration_session(tel.id) do
      with_complete_telephone_verification(:success, tel) do
        patch sign_app_configuration_telephones_registration_url(ri: "jp"),
              params: { user_telephone: { pass_code: "123456" } },
              headers: request_headers
      end
    end

    assert_redirected_to sign_app_configuration_telephones_url(ri: "jp")
    assert_equal "configuration_telephone", @token.reload.last_step_up_scope
    assert_not_nil @token.reload.last_step_up_at
  end

  test "update handles session_expired from verification" do
    tel = ClientTelephone.create!(
      user: @user,
      raw_number: "+19999999999",
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED,
      otp_private_key: "secret_credential",
      otp_expires_at: 10.minutes.from_now,
    )
    set_registration_session(tel.id) do
      with_complete_telephone_verification(:session_expired, tel) do
        patch sign_app_configuration_telephones_registration_url(ri: "jp"),
              params: { user_telephone: { pass_code: "123456" } },
              headers: request_headers

        assert_redirected_to new_sign_app_configuration_telephones_registration_url(ri: "jp")
        assert_equal I18n.t("sign.app.registration.telephone.edit.session_expired"), flash[:notice]
      end
    end
  end

  test "update handles locked from verification" do
    tel = ClientTelephone.create!(
      user: @user,
      raw_number: "+19999999999",
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED,
      otp_private_key: "secret_credential",
      otp_expires_at: 10.minutes.from_now,
    )
    set_registration_session(tel.id) do
      with_complete_telephone_verification(:locked, tel) do
        patch sign_app_configuration_telephones_registration_url(ri: "jp"),
              params: { user_telephone: { pass_code: "123456" } },
              headers: request_headers

        assert_redirected_to new_sign_app_configuration_telephones_registration_url(ri: "jp")
        assert_equal I18n.t("sign.app.registration.telephone.update.attempts_exceeded"), flash[:alert]
      end
    end
  end

  test "update handles invalid code from verification" do
    tel = ClientTelephone.create!(
      user: @user,
      raw_number: "+19999999999",
      user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED,
      otp_private_key: "secret_credential",
      otp_expires_at: 10.minutes.from_now,
    )
    set_registration_session(tel.id) do
      with_complete_telephone_verification(:invalid_code, tel) do
        patch sign_app_configuration_telephones_registration_url(ri: "jp"),
              params: { user_telephone: { pass_code: "123456" } },
              headers: request_headers

        assert_response :unprocessable_content
      end
    end
  end

  private

  def set_registration_session(id)
    # Using the backdoor or stubs. Since it's integration test, let's use a workaround.
    original_method = Sign::App::Configuration::Telephones::RegistrationsController.instance_method(:current_registration_telephone)
    Sign::App::Configuration::Telephones::RegistrationsController.define_method(:current_registration_telephone) do
      ClientTelephone.find(id)
    end

    begin
      yield if block_given?
    ensure
      Sign::App::Configuration::Telephones::RegistrationsController.define_method(
        :current_registration_telephone,
        original_method,
      )
    end
  end

  def with_complete_telephone_verification(status, telephone)
    original_method =
      Sign::App::Configuration::Telephones::RegistrationsController.instance_method(:complete_telephone_verification)
    Sign::App::Configuration::Telephones::RegistrationsController.define_method(
      :complete_telephone_verification,
    ) do |*_args, &block|
      block.call(telephone) if status == :success && block
      status
    end
    yield
  ensure
    Sign::App::Configuration::Telephones::RegistrationsController.define_method(
      :complete_telephone_verification,
      original_method,
    )
  end
end
