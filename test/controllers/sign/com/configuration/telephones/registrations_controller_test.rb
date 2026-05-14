# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Configuration::Telephones::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    host! ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @visitor = create_verified_visitor_with_email(email_address: "registration-#{SecureRandom.hex(4)}@example.com")
    @token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    satisfy_visitor_verification(@token)
    @token.update!(last_step_up_at: Time.current, last_step_up_scope: "configuration_telephone")

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
      "X-TEST-CURRENT-RESOURCE" => @visitor.id,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end

  test "new does not require step-up while registering first telephone" do
    visitor = create_verified_visitor_with_email(email_address: "first-telephone-#{SecureRandom.hex(4)}@example.com")
    token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)

    get(
      new_sign_com_configuration_telephones_registration_url(ri: "jp"),
      headers: request_headers_for(visitor, token),
    )

    assert_response :success
  end

  test "new requires step-up when visitor already has verified telephone" do
    visitor = create_verified_visitor_with_email(email_address: "existing-telephone-#{SecureRandom.hex(4)}@example.com")
    visitor.visitor_telephones.create!(
      raw_number: "+10000000040",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)

    get(
      new_sign_com_configuration_telephones_registration_url(ri: "jp"),
      headers: request_headers_for(visitor, token),
    )

    assert_response :redirect
    assert_match(%r{/verification}, response.location)
    assert_includes response.location, "scope=configuration_telephone"
  end

  test "create registers telephone for current visitor" do
    assert_enqueued_jobs 1, only: SmsDeliveryJob do
      assert_difference("VisitorTelephone.count", 1) do
        post sign_com_configuration_telephones_registration_url(ri: "jp"),
             params: { user_telephone: { raw_number: "+10000000039" } },
             headers: request_headers
      end
    end

    assert_response :redirect
    assert_redirected_to edit_sign_com_configuration_telephones_registration_url(ri: "jp")

    visitor_telephone = VisitorTelephone.order(created_at: :desc).first

    assert_equal @visitor.id, visitor_telephone.visitor_id
    assert_equal VisitorTelephoneStatus::UNVERIFIED, visitor_telephone.visitor_telephone_status_id
  end

  test "new renders stealth turnstile" do
    get(
      new_sign_com_configuration_telephones_registration_url(ri: "jp"),
      headers: request_headers,
    )

    assert_response :success
    assert_select "input[name='cf-turnstile-response'][type='hidden']", count: 1
    assert_includes response.body, "turnstile.execute"
  end

  test "update successfully verifies telephone" do
    telephone = VisitorTelephone.create!(
      visitor: @visitor,
      raw_number: "+19999999999",
      visitor_telephone_status_id: VisitorTelephoneStatus::UNVERIFIED,
      otp_private_key: "secret",
      otp_expires_at: 10.minutes.from_now,
    )

    with_current_registration_telephone(telephone) do
      original_method = Sign::Com::Configuration::Telephones::RegistrationsController.instance_method(:complete_visitor_telephone_verification)
      Sign::Com::Configuration::Telephones::RegistrationsController.define_method(
        :complete_visitor_telephone_verification,
      ) do |*_args, &block|
        block.call(telephone)
        :success
      end

      begin
        patch(
          sign_com_configuration_telephones_registration_url(ri: "jp"),
          params: { user_telephone: { pass_code: "123456" } },
          headers: request_headers,
        )

        assert_redirected_to sign_com_configuration_telephones_url(ri: "jp")
        assert_equal I18n.t("sign.app.registration.telephone.update.success"), flash[:notice]
      ensure
        Sign::Com::Configuration::Telephones::RegistrationsController.define_method(
          :complete_visitor_telephone_verification, original_method,
        )
      end
    end
  end

  test "direct controller telephone registration branches" do
    controller = Sign::Com::Configuration::Telephones::RegistrationsController.new
    session_hash = {}
    params_hash = ActionController::Parameters.new(ri: "jp")
    redirects = []
    renders = []
    heads = []

    controller.request = ActionDispatch::TestRequest.create("HTTP_HOST" => @host)
    controller.response = ActionDispatch::TestResponse.new
    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:params) { params_hash }
    controller.define_singleton_method(:flash) { @flash ||= {}.freeze }
    controller.define_singleton_method(:current_visitor) { @visitor_for_test }
    controller.instance_variable_set(:@visitor_for_test, @visitor)
    controller.define_singleton_method(:redirect_to) { |path, **kwargs| redirects << [path, kwargs] }
    controller.define_singleton_method(:render) { |*args, **kwargs| renders << [args, kwargs] }
    controller.define_singleton_method(:head) { |status| heads << status }
    controller.define_singleton_method(:t) { |key, **| key }
    controller.define_singleton_method(:new_sign_com_configuration_telephones_registration_path) { |ri: nil|
      "/configuration/telephones/registration/new?ri=#{ri}"
    }
    controller.define_singleton_method(:edit_sign_com_configuration_telephones_registration_path) { |ri: nil|
      "/configuration/telephones/registration/edit?ri=#{ri}"
    }
    controller.define_singleton_method(:sign_com_configuration_telephones_path) { |ri: nil|
      "/configuration/telephones?ri=#{ri}"
    }

    controller.new

    assert_instance_of VisitorTelephone, controller.instance_variable_get(:@user_telephone)
    assert_nil session_hash[controller.send(:registration_session_key)]

    controller.instance_variable_set(:@visitor_for_test, nil)
    params_hash[:user_telephone] = { raw_number: "+819011111111" }
    controller.create

    assert_equal :unauthorized, heads.last

    controller.instance_variable_set(:@visitor_for_test, @visitor)
    controller.define_singleton_method(:initiate_visitor_telephone_verification) { |*, **| false }
    controller.create

    assert_equal [[:new], { status: :unprocessable_content }], renders.last

    telephone = VisitorTelephone.create!(
      visitor: @visitor,
      raw_number: "+819011111112",
      visitor_telephone_status_id: VisitorTelephoneStatus::UNVERIFIED,
      otp_expires_at: 10.minutes.from_now,
    )
    session_hash[controller.send(:registration_session_key)] = telephone.id

    assert_equal telephone, controller.send(:current_registration_telephone)
    controller.instance_variable_set(:@user_telephone, telephone)

    assert controller.send(:valid_registration_session?)

    session_hash.delete(controller.send(:registration_session_key))
    controller.instance_variable_set(:@user_telephone, nil)

    assert_not controller.send(:valid_registration_session?)
    controller.edit

    assert_equal(
      ["/configuration/telephones/registration/new?ri=jp",
       { notice: "sign.app.registration.telephone.edit.session_expired" },],
      redirects.last,
    )

    session_hash[controller.send(:registration_session_key)] = telephone.id
    controller.instance_variable_set(:@user_telephone, telephone)
    params_hash[:user_telephone] = { pass_code: "" }
    controller.define_singleton_method(:current_registration_telephone) { telephone }
    controller.update

    assert_equal [[:edit], { status: :unprocessable_content }], renders.last

    params_hash[:user_telephone] = { pass_code: "123456" }
    controller.define_singleton_method(:complete_visitor_telephone_verification) { |*, **| :session_expired }
    controller.update

    assert_equal(
      ["/configuration/telephones/registration/new?ri=jp",
       { notice: "sign.app.registration.telephone.edit.session_expired" },],
      redirects.last,
    )

    controller.define_singleton_method(:complete_visitor_telephone_verification) { |*, **| :locked }
    controller.update

    assert_equal(
      ["/configuration/telephones/registration/new?ri=jp",
       { alert: "sign.app.registration.telephone.update.attempts_exceeded" },],
      redirects.last,
    )

    controller.define_singleton_method(:complete_visitor_telephone_verification) { |*, **| :invalid_code }
    controller.update

    assert_equal [[:edit], { status: :unprocessable_content }], renders.last

    assert_not controller.send(:verification_required_action?)

    @visitor.visitor_telephones.create!(
      raw_number: "+10000000041",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )

    assert controller.send(:verification_required_action?)
    assert_equal "configuration_telephone", controller.send(:verification_scope)
  end

  private

  def request_headers_for(visitor, token)
    {
      "Host" => @host,
      "X-TEST-CURRENT-RESOURCE" => visitor.id,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end

  def with_current_registration_telephone(telephone)
    original_method =
      Sign::Com::Configuration::Telephones::RegistrationsController.instance_method(:current_registration_telephone)
    Sign::Com::Configuration::Telephones::RegistrationsController.define_method(:current_registration_telephone) do
      telephone
    end
    yield
  ensure
    Sign::Com::Configuration::Telephones::RegistrationsController.define_method(
      :current_registration_telephone,
      original_method,
    )
  end
end
