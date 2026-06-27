# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Auth::App::Verification::PasskeysControllerTest < ActionDispatch::IntegrationTest
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
    return_to = Base64.urlsafe_encode64(sign_app_settings_emails_path(ri: "jp"))

    StepUpAvailableMethods.stub(:call, [:passkey]) do
      WebAuthn::Credential.stub(:options_for_get, OpenStruct.new(id: "test")) do
        WebAuthn::Credential.stub(:from_get, passkey_credential_stub("test")) do
          get sign_app_verification_url(scope: "settings_email", return_to: return_to, ri: "jp"),
              headers: @headers

          assert_response :success

          get new_sign_app_verification_passkey_url(
            ri: "jp",
            scope: "settings_email",
            return_to: return_to,
          ), headers: @headers

          assert_response :redirect
          assert_redirected_to sign_app_settings_url(ri: "jp")
        end
      end
    end
  end

  test "new keeps scope and return_to in form hidden fields" do
    return_to = Base64.urlsafe_encode64(sign_app_settings_emails_path(ri: "jp"))

    StepUpAvailableMethods.stub(:call, [:passkey]) do
      WebAuthn::Credential.stub(:options_for_get, OpenStruct.new(id: "test")) do
        get sign_app_verification_url(scope: "settings_email", return_to: return_to, ri: "jp"),
            headers: @headers

        assert_response :success

        get new_sign_app_verification_passkey_url(
          ri: "jp",
          scope: "settings_email",
          return_to: return_to,
        ), headers: @headers

        assert_response :redirect
        assert_redirected_to sign_app_settings_url(ri: "jp")
      end
    end
  end

  test "new keeps scope and pt in form hidden fields" do
    return_to = Base64.urlsafe_encode64(new_sign_app_settings_passkey_path(ri: "jp"))

    StepUpAvailableMethods.stub(:call, [:passkey]) do
      WebAuthn::Credential.stub(:options_for_get, OpenStruct.new(id: "test")) do
        get sign_app_verification_url(scope: "settings_passkey", return_to: return_to, ri: "jp"),
            headers: @headers

        assert_response :success
        assert_select "a[href^='#{new_sign_app_verification_passkey_path(ri: "jp")}']"

        get new_sign_app_verification_passkey_url(
          ri: "jp",
          scope: "settings_passkey",
          pt: return_to,
        ), headers: @headers

        assert_response :redirect
        assert_redirected_to sign_app_settings_url(ri: "jp")
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
