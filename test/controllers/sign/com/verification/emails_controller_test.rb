# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Sign::Com::Verification::EmailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_cache_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    host! @host
    @visitor = create_verified_visitor_with_email(email_address: "com-verified-#{SecureRandom.hex(4)}@example.com")
    @visitor.visitor_telephones.create!(
      number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    @headers = as_visitor_headers(@visitor, host: @host)
    @token = VisitorToken.find_by!(public_id: @headers["X-TEST-SESSION-PUBLIC-ID"])
  end

  teardown do
    Rails.cache = @previous_cache_store
  end

  test "new sends otp and redirects to edit" do
    return_to = sign_com_configuration_emails_path(ri: "jp")

    StepUp::AvailableMethods.stub(:call, [:email_otp]) do
      Email::Com::OtpMailer.stub(:with, OpenStruct.new(create: OpenStruct.new(deliver_later: true))) do
        get sign_com_verification_url(scope: "configuration_email", return_to: return_to, ri: "jp"),
            headers: @headers

        assert_response :success

        get new_sign_com_verification_email_url(ri: "jp"), headers: @headers

        assert_response :redirect
        assert_match %r{/verification/emails/.+/edit}, response.location

        follow_redirect!(headers: @headers)

        assert_response :success
      end
    end
  end

  test "new sends otp for email verified during signup" do
    @visitor.visitor_emails.update_all(visitor_email_status_id: VisitorEmailStatus::VERIFIED_WITH_SIGN_UP)
    return_to = Base64.urlsafe_encode64(sign_com_configuration_emails_path(ri: "jp"))

    StepUp::AvailableMethods.stub(:call, [:email_otp]) do
      get sign_com_verification_url(scope: "configuration_email", return_to: return_to, ri: "jp"),
          headers: @headers

      assert_response :success

      assert_enqueued_emails 1 do
        get new_sign_com_verification_email_url(ri: "jp"), headers: @headers
      end

      assert_response :redirect
      assert_match %r{/verification/emails/.+/edit}, response.location
    end
  end

  test "update verifies otp and redirects to return_to" do
    return_to = Base64.urlsafe_encode64(sign_com_configuration_emails_path(ri: "jp"))

    StepUp::AvailableMethods.stub(:call, [:email_otp]) do
      Email::Com::OtpMailer.stub(:with, OpenStruct.new(create: OpenStruct.new(deliver_later: true))) do
        get sign_com_verification_url(scope: "configuration_email", return_to: return_to, ri: "jp"),
            headers: @headers

        assert_response :success

        get new_sign_com_verification_email_url(ri: "jp"), headers: @headers

        assert_response :redirect
        nonce = response.location[%r{/verification/emails/([^/?]+)/edit}, 1]
        cache_email_nonce!(nonce)

        with_email_nonce_stub(true) do
          with_verify_email_otp_stub(true) do
            patch sign_com_verification_email_url(nonce, ri: "jp"),
                  params: { verification: { code: "123456" } },
                  headers: @headers

            assert_response :redirect
            assert_redirected_to sign_com_configuration_emails_url(ri: "jp")
            assert_nil @token.reload.step_up_session
          end
        end
      end
    end
  end

  test "invalid otp keeps back link from step_up session when request params are missing" do
    return_to = Base64.urlsafe_encode64(sign_com_configuration_emails_path(ri: "jp"))

    get sign_com_verification_url(scope: "configuration_email", rt: return_to, ri: "jp"),
        headers: @headers

    assert_response :success

    nonce = SecureRandom.urlsafe_base64(16)
    cache_email_nonce!(nonce)

    patch sign_com_verification_email_url(nonce, ri: "jp"),
          params: { verification: { code: "000000" } },
          headers: @headers

    assert_response :unprocessable_content
    assert_select(
      "a[href=?]",
      sign_com_verification_path(ri: "jp", scope: "configuration_email", return_to: return_to),
      text: I18n.t("sign.app.verification.edit.back"),
    )
    assert_select(
      "input[name='verification[return_to]'][value=?]",
      return_to,
    )
  end

  test "resend sends a new otp and returns to edit page" do
    return_to = Base64.urlsafe_encode64(sign_com_configuration_emails_path(ri: "jp"))

    get sign_com_verification_url(scope: "configuration_email", rt: return_to, ri: "jp"),
        headers: @headers

    assert_response :success

    nonce = SecureRandom.urlsafe_base64(16)
    cache_email_nonce!(nonce)

    assert_enqueued_emails 1 do
      post resend_sign_com_verification_email_url(
        nonce,
        ri: "jp",
        scope: "configuration_email",
        return_to: return_to,
      ), headers: @headers
    end

    assert_response :redirect
    assert_redirected_to edit_sign_com_verification_email_url(
      nonce,
      ri: "jp",
      scope: "configuration_email",
      return_to: return_to,
    )
    assert_equal I18n.t("otp.resend.sent"), flash[:notice]
    assert Rails.cache.exist?(email_otp_cache_key)
  end

  test "resend is rate limited" do
    return_to = Base64.urlsafe_encode64(sign_com_configuration_emails_path(ri: "jp"))

    get sign_com_verification_url(scope: "configuration_email", rt: return_to, ri: "jp"),
        headers: @headers

    assert_response :success

    nonce = SecureRandom.urlsafe_base64(16)
    cache_email_nonce!(nonce)

    assert_enqueued_emails 1 do
      post resend_sign_com_verification_email_url(nonce, ri: "jp"), headers: @headers
    end

    assert_enqueued_emails 0 do
      post resend_sign_com_verification_email_url(nonce, ri: "jp"), headers: @headers
    end

    assert_response :redirect
    assert_equal I18n.t("otp.resend.too_soon"), flash[:alert]
  end

  test "new renders translated error when no verified email is available" do
    return_to = Base64.urlsafe_encode64(sign_com_configuration_emails_path(ri: "jp"))

    get sign_com_verification_url(scope: "configuration_email", return_to: return_to, ri: "jp"),
        headers: @headers

    assert_response :success

    @visitor.visitor_emails.find_each do |email|
      assert email.update(visitor_email_status_id: VisitorEmailStatus::UNVERIFIED)
    end

    StepUp::AvailableMethods.stub(:call, [:email_otp]) do
      get new_sign_com_verification_email_url(ri: "jp"), headers: @headers

      assert_response :unprocessable_content
      assert_includes response.body, I18n.t("sign.app.verification.errors.email_not_verified").delete("。")
    end
  end

  test "direct base controller verification branches" do
    controller = Sign::Com::Verification::BaseController.new
    redirects = []

    controller.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp") }
    controller.define_singleton_method(:current_visitor) { @visitor_for_test }
    controller.instance_variable_set(:@visitor_for_test, @visitor)
    controller.define_singleton_method(:actor_token) { @token_for_test }
    controller.define_singleton_method(:current_session_token) { @token_for_test }
    controller.instance_variable_set(:@token_for_test, @token)
    controller.define_singleton_method(:safe_internal_path) { |path| path.to_s.start_with?("/") ? path : nil }
    controller.define_singleton_method(:safe_redirect_to) { |*args, **kwargs| redirects << [args, kwargs] }
    controller.define_singleton_method(:sign_com_verification_path) { |params = {}| "/verification?#{params.to_query}" }
    controller.define_singleton_method(:verification_recovery_redirect_params) { { ri: params[:ri] } }
    controller.define_singleton_method(:restore_step_up_session_from_params!) { @restore_for_test }
    controller.define_singleton_method(:current_step_up_session) {
      VisitorStepUpSession.find_by(visitor_token: @token_for_test)
    }
    controller.define_singleton_method(:generate_hotp_code) { ["secret", 1, "123456"] }

    return_to = Base64.urlsafe_encode64(sign_com_configuration_emails_path(ri: "jp"))
    controller.send(:start_step_up_session!, scope: "configuration_email", return_to_param: return_to)
    step_up_session = @token.reload.step_up_session

    assert controller.send(:valid_step_up_session?, step_up_session)

    assert_raises(ActionController::BadRequest) do
      controller.send(:start_step_up_session!, scope: "unknown", return_to_param: return_to)
    end
    assert_raises(ActionController::BadRequest) do
      controller.send(:start_step_up_session!, scope: "configuration_email", return_to_param: "%%%")
    end

    Rails.cache.write("step_up_session:#{step_up_session.id}:email_otp", { "secret" => "old" })
    controller.instance_variable_set(:@restore_for_test, false)

    assert_not controller.send(:handle_invalid_step_up_session!)
    assert_nil Rails.cache.read("step_up_session:#{step_up_session.id}:email_otp")
    assert_match "/verification?", redirects.last.first.first

    controller.instance_variable_set(:@restore_for_test, true)
    controller.define_singleton_method(:restore_step_up_session_from_params!) do
      VisitorStepUpSession.upsert(
        {
          :visitor_token_id => actor_token.id,
          "scope" => "configuration_email",
          "return_to" => "/configuration/emails",
          "method" => nil,
          "status" => "PENDING",
          "attempt_count" => 0,
          "verified_at" => nil,
          "discarded_at" => 5.minutes.from_now,
          "purged_at" => 5.minutes.from_now,
        }, unique_by: "index_visitor_step_up_sessions_on_visitor_token_id",
      )
      true
    end

    assert controller.send(:handle_invalid_step_up_session!)

    assert_equal :visitor_token_id, controller.send(:step_up_session_token_foreign_key)
    assert_equal "/verification?ri=jp", controller.send(:verification_unavailable_redirect_path)
    assert_equal VisitorVerification, controller.send(:verification_model)
    assert_equal ClientChronicleEvent::STEP_UP_VERIFIED, controller.send(:verification_success_event_id)
    assert_equal "sign.app.verification.success.complete", controller.send(:verification_success_notice_key)
    assert_equal "/verification?ri=jp", controller.send(:verification_success_fallback_path)
    assert_equal ClientChronicleEvent, controller.send(:verification_audit_event_class)
    assert_equal ClientChronicleLevel, controller.send(:verification_audit_level_class)
    assert_equal ClientChronicleLevel::NOTHING, controller.send(:verification_default_activity_level_id)
    assert_equal ClientChronicle, controller.send(:verification_activity_model)
    assert_equal @visitor, controller.send(:current_verification_actor)
    assert_equal "Visitor", controller.send(:verification_actor_type)
    assert_equal :visitor_token_id, controller.send(:verification_token_foreign_key)
    assert_equal VisitorPasskey, controller.send(:verification_passkey_model)
    assert_equal "sign.app.verification.errors.no_passkey", controller.send(:verification_no_passkey_i18n_key)
    assert_equal %i(email_otp passkey), controller.send(:step_up_supported_methods)

    passkey = VisitorPasskey.new(visitor: @visitor)

    assert controller.send(:passkey_actor_matches?, passkey)

    Email::Com::OtpMailer.stub(:with, OpenStruct.new(create: OpenStruct.new(deliver_later: true))) do
      assert controller.send(:send_email_otp!)
    end
    assert_equal(
      { "secret" => "secret",
        "counter" => 1, },
      Rails.cache.read("step_up_session:#{controller.send(:current_step_up_session).id}:email_otp"),
    )
  end

  test "direct email controller action branches" do
    controller = Sign::Com::Verification::EmailsController.new
    redirects = []
    renders = []

    controller.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp", id: "nonce") }
    controller.define_singleton_method(:redirect_to) { |*args, **kwargs| redirects << [args, kwargs] }
    controller.define_singleton_method(:render) { |*args, **kwargs| renders << [args, kwargs] }
    controller.define_singleton_method(:require_step_up_session!) { @require_step_up_for_test }
    controller.define_singleton_method(:redirect_if_recent_verification_for_get!) { @recent_get_for_test }
    controller.define_singleton_method(:redirect_if_recent_verification_for_post!) { @recent_post_for_test }
    controller.define_singleton_method(:require_method_available!) { |method| @available_method_for_test == method }
    controller.define_singleton_method(:email_otp_session_active?) { @email_active_for_test }
    controller.define_singleton_method(:ensure_email_nonce!) { "nonce" }
    controller.define_singleton_method(:current_step_up_scope) { "configuration_email" }
    controller.define_singleton_method(:current_step_up_return_to_param) { "return-token" }
    controller.define_singleton_method(:edit_sign_com_verification_email_path) { |nonce, **kwargs|
      "/verification/emails/#{nonce}/edit?#{kwargs.to_query}"
    }
    controller.define_singleton_method(:send_email_otp!) { @send_email_for_test }
    controller.define_singleton_method(:verify_email_otp!) { @verify_email_for_test }
    controller.define_singleton_method(:consume_step_up_session!) { @consumed_for_test = true }

    controller.instance_variable_set(:@require_step_up_for_test, false)
    controller.new

    assert_empty redirects

    controller.instance_variable_set(:@require_step_up_for_test, true)
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

    controller.define_singleton_method(:current_step_up_session) { { "email_nonce" => "nonce" } }
    controller.define_singleton_method(:safe_redirect_to) { |*args, **kwargs| redirects << [args, kwargs] }
    controller.define_singleton_method(:sign_com_verification_path) { |params = {}| "/verification?#{params.to_query}" }
    controller.define_singleton_method(:verification_recovery_redirect_params) { { ri: params[:ri] } }

    assert controller.send(:require_email_nonce!)

    controller.define_singleton_method(:current_step_up_session) { { "email_nonce" => "other" } }

    assert_not controller.send(:require_email_nonce!)

    controller.define_singleton_method(:current_step_up_session) { { "email_nonce" => "nonce" } }
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

  def with_email_nonce_stub(result)
    original_method = Sign::Com::Verification::EmailsController.instance_method(:require_email_nonce!)
    Sign::Com::Verification::EmailsController.define_method(:require_email_nonce!) { result }
    yield
  ensure
    Sign::Com::Verification::EmailsController.define_method(:require_email_nonce!, original_method)
  end

  def cache_email_nonce!(nonce)
    rs = @token.reload.step_up_session
    Rails.cache.write("step_up_session:#{rs.id}:email_nonce", nonce, expires_in: 15.minutes)
  end

  def email_otp_cache_key
    rs = @token.reload.step_up_session
    "step_up_session:#{rs.id}:email_otp"
  end
end
