# typed: false
# frozen_string_literal: true

require "test_helper"

# Unit tests for the MFA intercept logic in Authentication::Base.
# Tests mfa_required_for?, complete_sign_in_or_start_mfa!, and related helpers.
class Auth::MfaInterceptUnitTest < ActiveSupport::TestCase
  fixtures :user_statuses

  test "mfa_required_for? returns false for user without multi_factor_enabled" do
    user = User.create!(multi_factor_enabled: false)
    controller = build_test_controller

    assert_not controller.send(:mfa_required_for?, user)
  end

  test "mfa_required_for? returns true for user with multi_factor_enabled" do
    user = User.create!(multi_factor_enabled: true)
    controller = build_test_controller

    assert controller.send(:mfa_required_for?, user)
  end

  test "mfa_required_for? returns false for non-User resources" do
    controller = build_test_controller

    assert_not controller.send(:mfa_required_for?, nil)
  end

  test "check_totp_requirement returns mfa_required status for MFA user" do
    user = User.create!(multi_factor_enabled: true)
    controller = build_test_controller

    result = controller.send(:check_totp_requirement, user)

    assert_equal({ status: :mfa_required }, result)
  end

  test "check_totp_requirement returns nil for non-MFA user" do
    user = User.create!(multi_factor_enabled: false)
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
    encoded = Base64.urlsafe_encode64("/configuration")

    result = controller.send(:resolve_mfa_return_to, encoded)

    assert_equal "/configuration", result
  end

  test "resolve_mfa_return_to rejects external URLs without allowed host" do
    controller = build_test_controller

    result = controller.send(:resolve_mfa_return_to, "https://evil.com/hack")

    assert_nil result
  end

  private

  # Build a minimal controller-like object that includes Authentication::Base for testing
  def build_test_controller
    controller_class =
      Class.new do
        include Common::Redirect
        include Authentication::Base

        attr_accessor :session

        define_method(:initialize) do
          @session = {}
        end

        define_method(:resource_class) do
          ::User
        end

        define_method(:token_class) do
          UserToken
        end

        define_method(:audit_class) do
          ::UserChronicle
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

        define_method(:sign_in_url_with_return) do |_rt|
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

        define_method(:respond_to?) do |name, *|
          (name == :sign_app_in_mfa_path) ? true : super
        end

        define_method(:sign_app_in_mfa_path) do |ri: nil|
          ri ? "/sign/in/mfa?ri=#{ri}" : "/sign/in/mfa"
        end
      end

    controller_class.new
  end
end
