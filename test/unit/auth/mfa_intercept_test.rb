# typed: false
# frozen_string_literal: true

require "test_helper"

# Unit tests for the MFA intercept logic in AuthenticationBase.
# Tests mfa_required_for?, establish_signed_in_session!, and related helpers.
class Auth::MfaInterceptUnitTest < ActiveSupport::TestCase
  fixtures :client_statuses

  test "mfa_required_for? returns false for user without mfa_level_enabled" do
    user = Client.create!(mfa_level_enabled: false)
    controller = build_test_controller

    assert_not controller.send(:mfa_required_for?, user)
  end

  test "mfa_required_for? returns true for user with mfa_level_enabled" do
    user = Client.create!(mfa_level_enabled: true)
    controller = build_test_controller

    assert controller.send(:mfa_required_for?, user)
  end

  test "mfa_required_for? returns true for user with full mfa_level_id" do
    user = Client.create!(mfa_level_id: ClientMfaLevel::FULL, mfa_level_enabled: true)
    controller = build_test_controller

    assert controller.send(:mfa_required_for?, user)
  end

  test "mfa_required_for? returns false for user with nothing mfa_level_id" do
    user = Client.create!(mfa_level_id: ClientMfaLevel::NOTHING)
    controller = build_test_controller

    assert_not controller.send(:mfa_required_for?, user)
  end

  test "mfa_required_for? returns false for non-Client resources" do
    controller = build_test_controller

    assert_not controller.send(:mfa_required_for?, nil)
  end

  test "check_totp_requirement returns mfa_required status for MFA user" do
    user = Client.create!(mfa_level_enabled: true)
    controller = build_test_controller

    result = controller.send(:check_totp_requirement, user)

    assert_equal({ status: :mfa_required }, result)
  end

  test "check_totp_requirement returns nil for non-MFA user" do
    user = Client.create!(mfa_level_enabled: false)
    controller = build_test_controller

    result = controller.send(:check_totp_requirement, user)

    assert_nil result
  end

  test "resolve_mfa_return_to returns nil for blank value" do
    controller = build_test_controller

    assert_nil controller.send(:resolve_mfa_return_to, nil)
    assert_nil controller.send(:resolve_mfa_return_to, "")
  end

  test "resolve_mfa_return_to decodes base64 internal path" do
    controller = build_test_controller
    encoded = Base64.urlsafe_encode64("/settings")

    result = controller.send(:resolve_mfa_return_to, encoded)

    assert_equal "/settings", result
  end

  test "resolve_mfa_return_to rejects external URLs without allowed host" do
    controller = build_test_controller

    result = controller.send(:resolve_mfa_return_to, "https://evil.com/hack")

    assert_nil result
  end

  test "complete_sign_in_or_start_mfa adds auth method to login audit context" do
    user = Client.create!(mfa_level_enabled: false)
    controller = build_test_controller
    captured = nil

    controller.define_singleton_method(:log_in) do |resource, **kwargs|
      captured = [resource, kwargs]
      { status: :success }
    end

    result = controller.send(
      :establish_signed_in_session!,
      user,
      pt: nil,
      ri: "jp",
      auth_method: "secret_credential",
    )

    assert_equal({ status: :success, redirect_path: "/dashboard" }, result)
    assert_equal user, captured.first
    assert_not captured.last[:require_totp_check]
    assert_equal({ auth_method: "secret_credential" }, captured.last[:audit_context])
  end

  test "complete_sign_in_or_start_mfa preserves explicit audit context" do
    user = Client.create!(mfa_level_enabled: false)
    controller = build_test_controller
    captured = nil

    controller.define_singleton_method(:log_in) do |resource, **kwargs|
      captured = [resource, kwargs]
      { status: :success }
    end

    controller.send(
      :establish_signed_in_session!,
      user,
      pt: nil,
      ri: "jp",
      auth_method: "social",
      audit_context: { auth_method: "oauth", provider: "google" },
    )

    assert_equal user, captured.first
    assert_equal(
      { auth_method: "oauth", provider: "google" },
      captured.last[:audit_context],
    )
  end

  private

  # Build a minimal controller-like object that includes AuthenticationBase for testing
  def build_test_controller
    controller_class =
      Class.new do
        include CommonRedirect
        include AuthenticationBase

        attr_accessor :session

        define_method(:initialize) do
          @session = {}
        end

        define_method(:resource_class) do
          ::Client
        end

        define_method(:token_class) do
          ClientToken
        end

        define_method(:audit_class) do
          ::ClientChronicle
        end

        define_method(:resource_type) do
          "user"
        end

        define_method(:resource_foreign_key) do
          :user_id
        end

        define_method(:test_header_key) do
          "X-TEST-CURRENT-USER"
        end

        define_method(:sign_in_url_with_pt) do |_rt|
          "/sign/in"
        end

        define_method(:am_i_user?) do
          true
        end

        define_method(:am_i_staff?) do
          false
        end

        define_method(:am_i_owner?) do
          false
        end

        define_method(:respond_to?) do |name, include_private = false|
          return true if name == :sign_app_sign_in_mfa_path

          super(name, include_private)
        end

        define_method(:sign_app_sign_in_mfa_path) do |ri: nil|
          ri ? "/sign/in/mfa?ri=#{ri}" : "/sign/in/mfa"
        end
      end

    controller_class.new
  end
end
