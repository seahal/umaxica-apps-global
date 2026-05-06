# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Auth::OmniauthCallbacksControllerTest < ActiveSupport::TestCase
  test "direct org omniauth callback branches" do
    controller = Sign::Org::Auth::OmniauthCallbacksController.new
    session_hash = {}
    redirects = []
    hard_rejects = []

    request = ActionDispatch::TestRequest.create("REQUEST_METHOD" => "GET", "REMOTE_ADDR" => "127.0.0.1")
    controller.request = request
    controller.response = ActionDispatch::TestResponse.new
    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp", provider: "google_org", message: "denied") }
    controller.define_singleton_method(:redirect_to) { |*args, **kwargs| redirects << [args, kwargs] }
    controller.define_singleton_method(:render_session_limit_hard_reject) { |**kwargs| hard_rejects << kwargs }
    controller.define_singleton_method(:new_sign_org_in_path) { "/org/in/new" }
    controller.define_singleton_method(:sign_org_in_session_path) { "/org/in/session" }
    controller.define_singleton_method(:sign_org_in_bulletin_path) { |ri: nil| "/org/in/bulletin?ri=#{ri}" }
    controller.define_singleton_method(:sign_org_root_path) { |ri: nil| "/org?ri=#{ri}" }
    controller.define_singleton_method(:sign_org_configuration_path) { "/org/configuration" }
    controller.define_singleton_method(:clear_social_auth_intent!) { @cleared_for_test = true }
    controller.define_singleton_method(:issue_bulletin!) { @issue_bulletin_for_test }
    controller.define_singleton_method(:log_in) { |*| @login_result_for_test }

    auth = { "provider" => "google_org", "info" => { "email" => " STAFF@example.COM " } }
    auth.define_singleton_method(:provider) { self["provider"] }

    controller.send(:handle_missing_auth)

    assert_match "/org/in/new", redirects.last.first.first

    assert_equal "staff@example.com", controller.send(:extract_email_from_auth, auth)
    assert_nil controller.send(:find_active_staff_by_google_email, nil)

    controller.send(:redirect_staff_not_found, auth)

    assert controller.instance_variable_get(:@cleared_for_test)
    assert_match "/org/in/new", redirects.last.first.first

    staff = OpenStruct.new(id: 10, login_allowed?: false)
    controller.send(:redirect_login_not_allowed, staff)

    assert_match "/org/in/new", redirects.last.first.first

    controller.send(
      :handle_login_result,
      { status: :session_limit_hard_reject, message: "full", http_status: :too_many_requests }, "Google org",
    )

    assert_equal({ message: "full", http_status: :too_many_requests }, hard_rejects.last)

    controller.send(:handle_login_result, { status: :session_limit_exceeded }, "Google org")

    assert_match "/org/in/session", redirects.last.first.first

    controller.send(:handle_login_result, { status: :unknown }, "Google org")

    assert_match "/org/in/new", redirects.last.first.first

    controller.send(:handle_login_result, { status: :success, restricted: true }, "Google org")

    assert_match "/org/in/session", redirects.last.first.first

    controller.instance_variable_set(:@issue_bulletin_for_test, true)
    controller.send(:handle_login_result, true, "Google org")

    assert_match "/org/in/bulletin", redirects.last.first.first

    controller.instance_variable_set(:@issue_bulletin_for_test, false)
    controller.send(:handle_login_result, true, "Google org")

    assert_match "/org?ri=jp", redirects.last.first.first

    controller.send(:handle_unexpected_error, StandardError.new("boom"), OpenStruct.new(provider: "google_org"))

    assert_match "/org/in/new", redirects.last.first.first

    controller.failure

    assert_match "/org/in/new", redirects.last.first.first

    OmniAuth.config.mock_auth[:google_org] = OpenStruct.new(provider: "google_org", uid: "uid")

    assert_equal "uid", controller.send(:mock_auth_from_test_mode).uid

    assert_equal "/org/in/new", controller.send(:social_auth_failure_redirect_path)
    assert_equal "/org/configuration", controller.send(:social_auth_success_redirect_path)
  ensure
    OmniAuth.config.mock_auth.delete(:google_org) if defined?(OmniAuth)
  end

  test "direct org omniauth action success path and csrf helpers" do
    controller = Sign::Org::Auth::OmniauthCallbacksController.new
    redirects = []
    request = ActionDispatch::TestRequest.create("REQUEST_METHOD" => "GET")
    auth = OpenStruct.new(provider: "google_org")
    request.env["omniauth.auth"] = auth
    controller.request = request
    controller.response = ActionDispatch::TestResponse.new

    staff = OpenStruct.new(id: 22, login_allowed?: true)
    controller.define_singleton_method(:params) { ActionController::Parameters.new(provider: "google_org") }
    controller.define_singleton_method(:redirect_to) { |*args, **kwargs| redirects << [args, kwargs] }
    controller.define_singleton_method(:validate_social_auth_state!) { @validated_for_test = true }
    controller.define_singleton_method(:find_staff_from_auth) { |value| @found_auth_for_test = value; staff }
    controller.define_singleton_method(:clear_social_auth_intent!) { @cleared_for_test = true }
    controller.define_singleton_method(:login_and_redirect) { |found_staff, found_auth|
      @login_args_for_test = [found_staff, found_auth].freeze
    }
    controller.define_singleton_method(:action_name) { @action_name_for_test }
    controller.define_singleton_method(:verified_social_callback_request?) { @verified_social_for_test }
    controller.define_singleton_method(:reject_social_callback!) { |**kwargs| @rejection_for_test = kwargs }

    controller.omniauth

    assert controller.instance_variable_get(:@validated_for_test)
    assert_equal auth, controller.instance_variable_get(:@found_auth_for_test)
    assert controller.instance_variable_get(:@cleared_for_test)
    assert_equal [staff, auth], controller.instance_variable_get(:@login_args_for_test)

    controller.instance_variable_set(:@action_name_for_test, "omniauth")
    controller.instance_variable_set(:@verified_social_for_test, true)

    assert controller.send(:verified_request?)

    request.env["social_callback_guard.rejection"] = { reason: "bad_state", provider: "google_org", details: {} }
    controller.send(:handle_unverified_request)

    assert_equal "bad_state", controller.instance_variable_get(:@rejection_for_test)[:reason]
  end
end
