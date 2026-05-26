# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Sign::App::Verification::PasskeysControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients

  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = clients(:one)
    ClientEmail.create!(
      user: @user,
      address: "app-passkey-stepup-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    @headers = as_user_headers(@user, host: @host)
    @token = ClientToken.find_by!(public_id: @headers["X-TEST-SESSION-PUBLIC-ID"])
    @user.client_passkeys.create!(
      description: "Test passkey",
      webauthn_id: "test",
      public_key: "public_key",
      sign_count: 0,
      status_id: ClientPasskeyStatus::ACTIVE,
    )
  end

  test "creates verification on success" do
    return_to = Base64.urlsafe_encode64(sign_app_configuration_emails_path(ri: "jp"))

    StepUp::AvailableMethods.stub(:call, [:passkey]) do
      WebAuthn::Credential.stub(:options_for_get, OpenStruct.new(id: "test")) do
        WebAuthn::Credential.stub(:from_get, passkey_credential_stub("test")) do
          get sign_app_verification_url(scope: "configuration_email", return_to: return_to, ri: "jp"),
              headers: @headers

          assert_response :success

          get new_sign_app_verification_passkey_url(ri: "jp"), headers: @headers

          assert_response :success

          post sign_app_verification_passkey_url(ri: "jp"),
               params: { verification: { challenge_id: "test", credential_json: '{"id":"test"}' } },
               headers: @headers

          assert_response :redirect
          assert_redirected_to sign_app_configuration_emails_url(ri: "jp")
        end
      end
    end
  end

  test "new keeps scope and return_to in form hidden fields" do
    return_to = Base64.urlsafe_encode64(sign_app_configuration_emails_path(ri: "jp"))

    StepUp::AvailableMethods.stub(:call, [:passkey]) do
      WebAuthn::Credential.stub(:options_for_get, OpenStruct.new(id: "test")) do
        get sign_app_verification_url(scope: "configuration_email", return_to: return_to, ri: "jp"),
            headers: @headers

        assert_response :success

        get new_sign_app_verification_passkey_url(
          ri: "jp",
          scope: "configuration_email",
          return_to: return_to,
        ), headers: @headers

        assert_response :success
        assert_select "input[name='verification[scope]'][value='configuration_email']"
        assert_select "input[name='verification[return_to]'][value='#{return_to}']"
      end
    end
  end

  test "new keeps scope and pt in form hidden fields" do
    return_to = Base64.urlsafe_encode64(new_sign_app_configuration_passkey_path(ri: "jp"))

    StepUp::AvailableMethods.stub(:call, [:passkey]) do
      WebAuthn::Credential.stub(:options_for_get, OpenStruct.new(id: "test")) do
        get sign_app_verification_url(scope: "configuration_passkey", return_to: return_to, ri: "jp"),
            headers: @headers

        assert_response :success
        assert_select(
          "a[href=?]",
          new_sign_app_verification_passkey_path(ri: "jp", scope: "configuration_passkey", pt: return_to),
        )

        get new_sign_app_verification_passkey_url(
          ri: "jp",
          scope: "configuration_passkey",
          pt: return_to,
        ), headers: @headers

        assert_response :success
        assert_select "input[name='verification[scope]'][value='configuration_passkey']"
        assert_select "input[name='verification[return_to]'][value='#{return_to}']"
      end
    end
  end

  private

  def passkey_credential_stub(id)
    Struct.new(:id, :sign_count) do
      define_method(:verify) do |*|
        true
      end
    end.new(id, 1)
  end
end
