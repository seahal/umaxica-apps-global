# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Sign::Com::Verification::EmailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    host! @host
    @customer = create_verified_customer_with_email(email_address: "com-verified-#{SecureRandom.hex(4)}@example.com")
    @customer.customer_telephones.create!(
      number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
      customer_telephone_status_id: CustomerTelephoneStatus::VERIFIED,
    )
    @headers = as_customer_headers(@customer, host: @host)
    @token = CustomerToken.find_by!(public_id: @headers["X-TEST-SESSION-PUBLIC-ID"])
  end

  test "new sends otp and redirects to edit" do
    return_to = Base64.urlsafe_encode64(sign_com_configuration_emails_path(ri: "jp"))

    StepUp::AvailableMethods.stub(:call, [:email_otp]) do
      Email::App::RegistrationMailer.stub(:with, OpenStruct.new(create: OpenStruct.new(deliver_later: true))) do
        get sign_com_verification_url(scope: "configuration_email", return_to: return_to, ri: "jp"),
            headers: @headers

        assert_response :success

        get new_sign_com_verification_email_url(ri: "jp"), headers: @headers

        assert_response :redirect
        assert_match %r{/verification/emails/.+/edit}, response.location
      end
    end
  end

  test "update verifies otp and redirects to return_to" do
    return_to = Base64.urlsafe_encode64(sign_com_configuration_emails_path(ri: "jp"))

    StepUp::AvailableMethods.stub(:call, [:email_otp]) do
      Email::App::RegistrationMailer.stub(:with, OpenStruct.new(create: OpenStruct.new(deliver_later: true))) do
        get sign_com_verification_url(scope: "configuration_email", return_to: return_to, ri: "jp"),
            headers: @headers

        assert_response :success

        get new_sign_com_verification_email_url(ri: "jp"), headers: @headers

        assert_response :redirect
        nonce = response.location[%r{/verification/emails/([^/]+)/edit}, 1]

        with_verify_email_otp_stub(true) do
          patch sign_com_verification_email_url(nonce, ri: "jp"),
                params: { verification: { code: "123456" } },
                headers: @headers

          assert_response :redirect
          assert_redirected_to sign_com_configuration_emails_url(ri: "jp")
        end
      end
    end
  end

  test "new renders translated error when no verified email is available" do
    return_to = Base64.urlsafe_encode64(sign_com_configuration_emails_path(ri: "jp"))

    get sign_com_verification_url(scope: "configuration_email", return_to: return_to, ri: "jp"),
        headers: @headers

    assert_response :success

    @customer.customer_emails.find_each do |email|
      assert email.update(customer_email_status_id: CustomerEmailStatus::UNVERIFIED)
    end

    StepUp::AvailableMethods.stub(:call, [:email_otp]) do
      get new_sign_com_verification_email_url(ri: "jp"), headers: @headers

      assert_response :unprocessable_content
      assert_includes response.body, I18n.t("sign.app.verification.errors.email_not_verified").delete("。")
    end
  end

  test "direct base controller verification branches" do
    controller = Sign::Com::Verification::BaseController.new
    session_hash = {}
    redirects = []

    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp") }
    controller.define_singleton_method(:current_customer) { @customer_for_test }
    controller.instance_variable_set(:@customer_for_test, @customer)
    controller.define_singleton_method(:safe_internal_path) { |path| path.to_s.start_with?("/") ? path : nil }
    controller.define_singleton_method(:safe_redirect_to) { |*args, **kwargs| redirects << [args, kwargs] }
    controller.define_singleton_method(:sign_com_verification_path) { |params = {}| "/verification?#{params.to_query}" }
    controller.define_singleton_method(:verification_recovery_redirect_params) { { ri: params[:ri] } }
    controller.define_singleton_method(:restore_reauth_session_from_params!) { @restore_for_test }
    controller.define_singleton_method(:current_reauth_session) { session[self.class::REAUTH_SESSION_KEY] }
    controller.define_singleton_method(:generate_hotp_code) { ["secret", 1, "123456"] }

    return_to = Base64.urlsafe_encode64(sign_com_configuration_emails_path(ri: "jp"))
    controller.send(:start_reauth_session!, scope: "configuration_email", return_to_param: return_to)

    assert controller.send(:valid_reauth_session?, session_hash[Sign::Com::Verification::BaseController::REAUTH_SESSION_KEY])

    assert_raises(ActionController::BadRequest) do
      controller.send(:start_reauth_session!, scope: "unknown", return_to_param: return_to)
    end
    assert_raises(ActionController::BadRequest) do
      controller.send(:start_reauth_session!, scope: "configuration_email", return_to_param: "%%%")
    end

    session_hash[Sign::Com::Verification::BaseController::EMAIL_OTP_SESSION_KEY] = { "secret" => "old" }
    controller.instance_variable_set(:@restore_for_test, false)

    assert_not controller.send(:handle_invalid_reauth_session!)
    assert_nil session_hash[Sign::Com::Verification::BaseController::REAUTH_SESSION_KEY]
    assert_nil session_hash[Sign::Com::Verification::BaseController::EMAIL_OTP_SESSION_KEY]
    assert_match "/verification?", redirects.last.first.first

    controller.instance_variable_set(:@restore_for_test, true)
    controller.define_singleton_method(:restore_reauth_session_from_params!) do
      session[self.class::REAUTH_SESSION_KEY] = {
        "customer_id" => current_customer.id,
        "scope" => "configuration_email",
        "return_to" => "/configuration/emails",
        "expires_at" => 5.minutes.from_now.to_i,
      }
    end

    assert controller.send(:handle_invalid_reauth_session!)

    assert_equal @customer.id, controller.send(:reauth_actor_id)
    assert_equal "/verification?ri=jp", controller.send(:verification_unavailable_redirect_path)
    assert_equal CustomerVerification, controller.send(:verification_model)
    assert_equal UserChronicleEvent::STEP_UP_VERIFIED, controller.send(:verification_success_event_id)
    assert_equal "sign.app.verification.success.complete", controller.send(:verification_success_notice_key)
    assert_equal "/verification?ri=jp", controller.send(:verification_success_fallback_path)
    assert_equal UserChronicleEvent, controller.send(:verification_audit_event_class)
    assert_equal UserChronicleLevel, controller.send(:verification_audit_level_class)
    assert_equal UserChronicleLevel::NOTHING, controller.send(:verification_default_activity_level_id)
    assert_equal UserChronicle, controller.send(:verification_activity_model)
    assert_equal @customer, controller.send(:current_verification_actor)
    assert_equal "Customer", controller.send(:verification_actor_type)
    assert_equal :customer_token_id, controller.send(:verification_token_foreign_key)
    assert_equal CustomerPasskey, controller.send(:verification_passkey_model)
    assert_equal "sign.app.verification.errors.no_passkey", controller.send(:verification_no_passkey_i18n_key)
    assert_equal [], controller.send(:active_totp_credentials)
    assert_equal %i(email_otp passkey), controller.send(:step_up_supported_methods)

    passkey = CustomerPasskey.new(customer: @customer)

    assert controller.send(:passkey_actor_matches?, passkey)

    Email::App::RegistrationMailer.stub(:with, OpenStruct.new(create: OpenStruct.new(deliver_later: true))) do
      assert controller.send(:send_email_otp!)
    end
    assert_equal(
      { "secret" => "secret",
        "counter" => 1,
        "expires_at" => session_hash[Sign::Com::Verification::BaseController::REAUTH_SESSION_KEY]["expires_at"], },
      session_hash[Sign::Com::Verification::BaseController::EMAIL_OTP_SESSION_KEY],
    )
  end

  test "direct email controller action branches" do
    controller = Sign::Com::Verification::EmailsController.new
    redirects = []
    renders = []

    controller.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp", id: "nonce") }
    controller.define_singleton_method(:redirect_to) { |*args, **kwargs| redirects << [args, kwargs] }
    controller.define_singleton_method(:render) { |*args, **kwargs| renders << [args, kwargs] }
    controller.define_singleton_method(:require_reauth_session!) { @require_reauth_for_test }
    controller.define_singleton_method(:redirect_if_recent_verification_for_get!) { @recent_get_for_test }
    controller.define_singleton_method(:redirect_if_recent_verification_for_post!) { @recent_post_for_test }
    controller.define_singleton_method(:require_method_available!) { |method| @available_method_for_test == method }
    controller.define_singleton_method(:email_otp_session_active?) { @email_active_for_test }
    controller.define_singleton_method(:ensure_email_nonce!) { "nonce" }
    controller.define_singleton_method(:current_reauth_scope) { "configuration_email" }
    controller.define_singleton_method(:current_reauth_return_to_param) { "return-token" }
    controller.define_singleton_method(:edit_sign_com_verification_email_path) { |nonce, **kwargs|
      "/verification/emails/#{nonce}/edit?#{kwargs.to_query}"
    }
    controller.define_singleton_method(:send_email_otp!) { @send_email_for_test }
    controller.define_singleton_method(:verify_email_otp!) { @verify_email_for_test }
    controller.define_singleton_method(:consume_reauth_session!) { @consumed_for_test = true }

    controller.instance_variable_set(:@require_reauth_for_test, false)
    controller.new

    assert_empty redirects

    controller.instance_variable_set(:@require_reauth_for_test, true)
    controller.instance_variable_set(:@recent_get_for_test, true)
    controller.new

    assert_empty redirects

    controller.instance_variable_set(:@recent_get_for_test, false)
    controller.instance_variable_set(:@available_method_for_test, :passkey)
    controller.new

    assert_empty redirects

    controller.instance_variable_set(:@available_method_for_test, :email_otp)
    controller.instance_variable_set(:@email_active_for_test, true)
    controller.new

    assert_match %r{/verification/emails/nonce/edit}, redirects.last.first.first

    controller.instance_variable_set(:@email_active_for_test, false)
    controller.instance_variable_set(:@send_email_for_test, false)
    controller.create

    assert_equal [[:new], { status: :unprocessable_content }], renders.last

    controller.instance_variable_set(:@send_email_for_test, true)
    controller.create

    assert_match %r{/verification/emails/nonce/edit}, redirects.last.first.first

    controller.define_singleton_method(:current_reauth_session) { { "email_nonce" => "nonce" } }
    controller.define_singleton_method(:safe_redirect_to) { |*args, **kwargs| redirects << [args, kwargs] }
    controller.define_singleton_method(:sign_com_verification_path) { |params = {}| "/verification?#{params.to_query}" }
    controller.define_singleton_method(:verification_recovery_redirect_params) { { ri: params[:ri] } }

    assert controller.send(:require_email_nonce!)

    controller.define_singleton_method(:current_reauth_session) { { "email_nonce" => "other" } }

    assert_not controller.send(:require_email_nonce!)

    controller.define_singleton_method(:current_reauth_session) { { "email_nonce" => "nonce" } }
    controller.instance_variable_set(:@recent_post_for_test, false)
    controller.instance_variable_set(:@verify_email_for_test, false)
    controller.update

    assert_equal [[:edit], { status: :unprocessable_content }], renders.last

    controller.instance_variable_set(:@verify_email_for_test, true)
    controller.update

    assert controller.instance_variable_get(:@consumed_for_test)
  end

  private

  def with_verify_email_otp_stub(result)
    original_method = Sign::Com::Verification::EmailsController.instance_method(:verify_email_otp!)
    Sign::Com::Verification::EmailsController.define_method(:verify_email_otp!) { result }
    yield
  ensure
    Sign::Com::Verification::EmailsController.define_method(:verify_email_otp!, original_method)
  end
end
