# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Sign::App::Verification::EmailsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users

  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = users(:one)
    @headers = as_user_headers(@user, host: @host)
    @token = UserToken.find_by!(public_id: @headers["X-TEST-SESSION-PUBLIC-ID"])
    UserEmail.create!(
      user: @user,
      address: "verified-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: UserEmailStatus::VERIFIED,
      otp_private_key: "otp_private_key",
      otp_counter: "0",
    )
  end

  test "new sends otp and redirects to edit" do
    return_to = Base64.urlsafe_encode64(sign_app_configuration_emails_path(ri: "jp"))

    StepUp::AvailableMethods.stub(:call, [:email_otp]) do
      Email::App::RegistrationMailer.stub(:with, OpenStruct.new(create: OpenStruct.new(deliver_later: true))) do
        get sign_app_verification_url(scope: "configuration_email", return_to: return_to, ri: "jp"),
            headers: @headers

        get new_sign_app_verification_email_url(ri: "jp"), headers: @headers

        assert_response :redirect

        assert_match %r{/verification/emails/.+/edit}, response.location
      end
    end
  end

  test "new keeps scope and return_to in form hidden fields" do
    return_to = Base64.urlsafe_encode64(sign_app_configuration_emails_path(ri: "jp"))

    StepUp::AvailableMethods.stub(:call, [:email_otp]) do
      get new_sign_app_verification_email_url(
        ri: "jp",
        scope: "configuration_email",
        return_to: return_to,
      ), headers: @headers
    end

    assert_response :redirect
    assert_match %r{/verification/emails/.+/edit}, response.location
  end

  test "update verifies otp and redirects to return_to" do
    return_to = Base64.urlsafe_encode64(sign_app_configuration_emails_path(ri: "jp"))

    StepUp::AvailableMethods.stub(:call, [:email_otp]) do
      Email::App::RegistrationMailer.stub(:with, OpenStruct.new(create: OpenStruct.new(deliver_later: true))) do
        get sign_app_verification_url(scope: "configuration_email", return_to: return_to, ri: "jp"),
            headers: @headers

        get new_sign_app_verification_email_url(ri: "jp"), headers: @headers
        nonce = response.location[%r{/verification/emails/([^/]+)/edit}, 1]

        with_verify_email_otp_stub(true) do
          patch sign_app_verification_email_url(nonce, ri: "jp"),
                params: { verification: { code: "123456" } },
                headers: @headers

          assert_response :redirect
          assert_redirected_to sign_app_configuration_emails_url(ri: "jp")
        end
      end
    end
  end

  test "step up flow from configuration emails returns to original page" do
    stale_token = UserToken.create!(user_id: @user.id, created_at: 20.minutes.ago, updated_at: 20.minutes.ago)
    stale_headers = @headers.merge("X-TEST-SESSION-PUBLIC-ID" => stale_token.public_id)

    StepUp::AvailableMethods.stub(:call, [:email_otp]) do
      get sign_app_configuration_emails_url(ri: "jp"), headers: stale_headers

      assert_response :redirect

      query = Rack::Utils.parse_nested_query(URI(response.location).query)
      scope = query["scope"]
      return_to = query["rd"] || query["return_to"]

      assert_equal "configuration_email", scope
      assert_predicate return_to, :present?

      get sign_app_verification_url(scope: scope, rd: return_to, ri: "jp"), headers: stale_headers

      assert_response :success

      Email::App::RegistrationMailer.stub(:with, OpenStruct.new(create: OpenStruct.new(deliver_later: true))) do
        post sign_app_verification_emails_url(ri: "jp"),
             params: { verification: { scope: scope, rd: return_to } },
             headers: stale_headers
      end

      assert_response :redirect
      nonce = response.location[%r{/verification/emails/([^/]+)/edit}, 1]

      assert_predicate nonce, :present?

      with_verify_email_otp_stub(true) do
        patch sign_app_verification_email_url(nonce, ri: "jp"),
              params: { verification: { code: "123456", scope: scope, rd: return_to } },
              headers: stale_headers
      end

      assert_response :redirect
      assert_redirected_to sign_app_configuration_emails_url(ri: "jp")
    end
  end

  test "create restores reauth session only when scope and return_to are present" do
    StepUp::AvailableMethods.stub(:call, [:email_otp]) do
      Email::App::RegistrationMailer.stub(:with, OpenStruct.new(create: OpenStruct.new(deliver_later: true))) do
        post sign_app_verification_emails_url(ri: "jp"),
             params: { verification: { scope: "", return_to: "" } },
             headers: @headers

        assert_response :redirect
        assert_redirected_to sign_app_verification_url(ri: "jp")
      end

      return_to = Base64.urlsafe_encode64(sign_app_configuration_telephones_path(ri: "jp"))
      post sign_app_verification_emails_url(ri: "jp"),
           params: { verification: { scope: "configuration_telephone", return_to: return_to } },
           headers: @headers

      assert_response :redirect
      assert_match %r{/verification/emails/.+/edit}, response.location
    end
  end

  private

  def with_verify_email_otp_stub(result)
    original_method = Sign::App::Verification::EmailsController.instance_method(:verify_email_otp!)
    Sign::App::Verification::EmailsController.define_method(:verify_email_otp!) { result }
    yield
  ensure
    Sign::App::Verification::EmailsController.define_method(:verify_email_otp!, original_method)
  end
end
