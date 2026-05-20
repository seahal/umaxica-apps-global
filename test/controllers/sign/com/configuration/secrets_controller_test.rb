# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Configuration::SecretsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    Prosopite.pause do
      VisitorStatus.find_or_create_by!(id: VisitorStatus::ACTIVE)
      VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
      VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
      VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
      VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
      VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::NOTHING)
      VisitorTokenStatus.ensure_defaults!
      VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
      VisitorSecretKind.find_or_create_by!(id: VisitorSecretKind::LOGIN)
      VisitorSecretStatus.find_or_create_by!(id: VisitorSecretStatus::ACTIVE)
      VisitorSecretStatus.find_or_create_by!(id: VisitorSecretStatus::DELETED)
    end
    @visitor = Visitor.create!(
      status_id: VisitorStatus::ACTIVE,
      visibility_id: VisitorVisibility::VISITOR,
    )
    VisitorEmail.create!(
      visitor: @visitor,
      address: "com-secret-#{SecureRandom.hex(4)}@example.com",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      confirm_policy: "1",
    )
    @visitor.visitor_telephones.create!(
      number: "+819000000001",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    @token = VisitorToken.create!(
      visitor: @visitor,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_binding_method_id: VisitorTokenBindingMethod::NOTHING,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      visitor_token_dbsc_status_id: VisitorTokenDbscStatus::NOTHING,
    )
    satisfy_visitor_verification(@token)
    @token.update!(last_step_up_at: Time.current, last_step_up_scope: "configuration_secret")

    @secret = VisitorSecret.create!(
      visitor: @visitor,
      name: "Login Secret",
      password: "a" * 32,
      visitor_secret_kind_id: VisitorSecretKind::LOGIN,
      visitor_secret_status_id: VisitorSecretStatus::ACTIVE,
      last_used_at: Time.current,
    )
  end

  def request_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-RESOURCE" => @visitor.id,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end

  test "index show new edit and access by public id" do
    get sign_com_configuration_secrets_url(ri: "jp"), headers: request_headers

    assert_response :success

    get sign_com_configuration_secret_url(@secret.public_id, ri: "jp"), headers: request_headers

    assert_response :success

    get new_sign_com_configuration_secret_url(ri: "jp"), headers: request_headers

    assert_response :success

    get edit_sign_com_configuration_secret_url(@secret.public_id, ri: "jp"), headers: request_headers

    assert_response :success
  end

  test "ensure_verified_recovery_identity_for_registration! renders forbidden " \
       "plain text when recovery identity is missing" do
    controller = Sign::Com::Configuration::SecretsController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.instance_variable_set(:@_response, ActionDispatch::Response.new)
    controller.define_singleton_method(:current_visitor) { Visitor.new }

    controller.send(:ensure_verified_recovery_identity_for_registration!)

    assert_equal 403, controller.response.status
    assert_includes controller.response.body, Visitor::RECOVERY_IDENTITY_REQUIRED_MESSAGE
  end

  test "create persists secret and redirects" do
    get new_sign_com_configuration_secret_url(ri: "jp"), headers: request_headers

    assert_response :success

    assert_difference("VisitorSecret.count", 1) do
      post sign_com_configuration_secrets_url(ri: "jp"),
           params: { visitor_secret: { name: "New Secret", enabled: true } },
           headers: request_headers
    end

    assert_redirected_to sign_com_configuration_secrets_url(ri: "jp")
    assert_predicate flash[:notice], :present?
  end

  test "destroy redirects when last recovery method would be removed" do
    AuthMethodGuard.stub(:last_method?, true) do
      delete sign_com_configuration_secret_url(@secret.public_id, ri: "jp"), headers: request_headers
    end

    assert_redirected_to sign_com_configuration_secrets_url(ri: "jp")
    assert_predicate flash[:alert], :present?
  end

  test "destroy removes secret and regenerate is not implemented" do
    visitor = create_verified_visitor_with_email(email_address: "com-secret-allow-#{SecureRandom.hex(4)}@example.com")
    visitor.visitor_telephones.create!(
      number: "+819000000002",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    satisfy_visitor_verification(token)
    token.update!(last_step_up_at: Time.current, last_step_up_scope: "configuration_secret")
    secret = VisitorSecret.create!(
      visitor: visitor,
      name: "Destroy Secret",
      password: "a" * 32,
      visitor_secret_kind_id: VisitorSecretKind::LOGIN,
      visitor_secret_status_id: VisitorSecretStatus::ACTIVE,
    )

    ClientSecrets::Destroy.stub(:call, true) do
      delete sign_com_configuration_secret_url(secret.public_id, ri: "jp"),
             headers: {
               "Host" => @host,
               "X-TEST-CURRENT-RESOURCE" => visitor.id,
               "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
             }
    end

    assert_response :see_other

    I18n.backend.store_translations(:ja, messages: { not_implemented: "Not implemented" })
    post regenerate_sign_com_configuration_secret_url(secret.public_id, ri: "jp"), headers: {
      "Host" => @host,
      "X-TEST-CURRENT-RESOURCE" => visitor.id,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :see_other
    assert_equal I18n.t("messages.not_implemented"), flash[:alert]
  end
end
