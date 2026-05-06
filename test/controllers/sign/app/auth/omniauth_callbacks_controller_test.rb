# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Auth::OmniauthCallbacksControllerTest < ActiveSupport::TestCase
  test "direct success and failure branches" do
    controller = Sign::App::Auth::OmniauthCallbacksController.new
    session_hash = {}
    redirects = []
    safe_redirects = []
    hard_rejects = []

    request = ActionDispatch::TestRequest.create(
      "REQUEST_METHOD" => "GET",
      "HTTP_HOST" => ENV.fetch("ID_SERVICE_URL", "id.app.localhost"),
      "REMOTE_ADDR" => "127.0.0.1",
    )
    controller.request = request
    controller.response = ActionDispatch::TestResponse.new

    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:params) { ActionController::Parameters.new(ri: "jp", provider: "apple") }
    controller.define_singleton_method(:redirect_to) { |*args, **kwargs| redirects << [args, kwargs] }
    controller.define_singleton_method(:safe_redirect_to) { |*args, **kwargs| safe_redirects << [args, kwargs] }
    controller.define_singleton_method(:render_session_limit_hard_reject) { |**kwargs| hard_rejects << kwargs }
    controller.define_singleton_method(:new_sign_app_in_path) { "/sign/in/new" }
    controller.define_singleton_method(:sign_app_configuration_path) { |ri: nil| "/configuration?ri=#{ri}" }
    controller.define_singleton_method(:sign_app_in_session_path) { "/sign/in/session" }
    controller.define_singleton_method(:sign_app_in_bulletin_path) { |ri: nil| "/sign/in/bulletin?ri=#{ri}" }
    controller.define_singleton_method(:social_auth_success_redirect_path) { "/configuration" }
    controller.define_singleton_method(:issue_bulletin!) { @issue_bulletin_for_test }
    controller.define_singleton_method(:logged_in?) { @logged_in_for_test }
    controller.define_singleton_method(:current_resource) { @resource_for_test }
    controller.define_singleton_method(:complete_sign_in_or_start_mfa!) { |*| @login_result_for_test }

    user = User.create!(status_id: UserStatus::NOTHING)

    controller.send(:handle_link_intent, "Apple")

    assert_match "/configuration", redirects.last.first.first

    controller.instance_variable_set(:@issue_bulletin_for_test, true)
    controller.send(:redirect_for_existing_account, "Apple")

    assert_match "/sign/in/bulletin", redirects.last.first.first

    controller.instance_variable_set(:@issue_bulletin_for_test, false)
    controller.send(:redirect_for_new_account, "Apple")

    assert_match "/configuration", redirects.last.first.first

    controller.send(:handle_reauth_intent, nil, "Apple")

    assert_match "/sign/in/new", redirects.last.first.first

    controller.instance_variable_set(:@login_result_for_test, { status: :session_limit_exceeded })
    controller.send(:handle_reauth_intent, user, "Apple")

    assert_match "/sign/in/session", redirects.last.first.first

    controller.instance_variable_set(:@login_result_for_test, { status: :success, restricted: true })
    controller.send(:handle_login_intent, user, "Apple", false)

    assert_match "/sign/in/session", redirects.last.first.first

    controller.instance_variable_set(:@login_result_for_test, true)
    controller.send(:handle_login_intent, user, "Apple", true)

    assert_match "/configuration", redirects.last.first.first

    controller.send(
      :handle_login_failure,
      { status: :session_limit_hard_reject, message: "full", http_status: :too_many_requests }, "Apple", user,
    )

    assert_equal({ message: "full", http_status: :too_many_requests }, hard_rejects.last)

    controller.send(:handle_login_failure, { status: :mfa_required, redirect_path: "/mfa" }, "Apple", user)

    assert_equal [["/mfa"], { fallback: "/sign/in/new", notice: I18n.t("sign.app.in.mfa.required") }],
                 safe_redirects.last

    controller.send(:handle_login_failure, { status: :unknown }, "Apple", user)

    assert_match "/sign/in/new", redirects.last.first.first

    auth = OpenStruct.new(provider: "apple")
    controller.define_singleton_method(:clear_social_auth_intent!) { @cleared_for_test = true }
    controller.send(:handle_unexpected_error, StandardError.new("boom"), auth)

    assert controller.instance_variable_get(:@cleared_for_test)
    assert_match "/sign/in/new", redirects.last.first.first
  end

  test "direct state and test mode helpers" do
    controller = Sign::App::Auth::OmniauthCallbacksController.new
    session_hash = {}
    user = User.create!(status_id: UserStatus::NOTHING)
    request = ActionDispatch::TestRequest.create(
      "REQUEST_METHOD" => "GET",
      "HTTP_X_TEST_CURRENT_USER" => user.id.to_s,
    )
    controller.request = request
    controller.response = ActionDispatch::TestResponse.new

    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:params) { ActionController::Parameters.new(provider: "apple") }
    controller.define_singleton_method(:logged_in?) { @logged_in_for_test }
    controller.define_singleton_method(:current_resource) { @resource_for_test }

    assert_equal user, controller.send(:test_user_from_header)
    assert controller.send(:auto_link_allowed?)
    assert_equal "link", controller.send(:current_social_auth_intent)
    assert_equal user.id, session_hash[SocialAuthConcern::SOCIAL_USER_ID_SESSION_KEY]

    session_hash[SocialAuthConcern::SOCIAL_INTENT_SESSION_KEY] = "reauth"

    assert_equal "reauth", controller.send(:current_social_auth_intent)

    controller.request = ActionDispatch::TestRequest.create("REQUEST_METHOD" => "POST")

    assert_not controller.send(:auto_link_allowed?)
  end

  test "direct action early exits and csrf helpers" do
    controller = Sign::App::Auth::OmniauthCallbacksController.new
    session_hash = {}
    redirects = []

    request = ActionDispatch::TestRequest.create("REQUEST_METHOD" => "GET")
    controller.request = request
    controller.response = ActionDispatch::TestResponse.new
    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:params) { ActionController::Parameters.new(provider: "apple", message: "cancelled", strategy: "apple") }
    controller.define_singleton_method(:redirect_to) { |*args, **kwargs| redirects << [args, kwargs] }
    controller.define_singleton_method(:new_sign_app_in_path) { "/sign/in/new" }
    controller.define_singleton_method(:clear_social_auth_intent!) { @cleared_for_test = true }
    controller.define_singleton_method(:action_name) { @action_name_for_test }
    controller.define_singleton_method(:verified_social_callback_request?) { @verified_social_for_test }
    controller.define_singleton_method(:reject_social_callback!) { |**kwargs| @rejection_for_test = kwargs }

    controller.omniauth

    assert_match "/sign/in/new", redirects.last.first.first

    controller.failure

    assert controller.instance_variable_get(:@cleared_for_test)
    assert_match "/sign/in/new", redirects.last.first.first

    controller.instance_variable_set(:@action_name_for_test, "omniauth")
    controller.instance_variable_set(:@verified_social_for_test, true)

    assert controller.send(:verified_request?)

    request.env["social_callback_guard.rejection"] =
      { reason: "bad_state", provider: "apple", details: { state_reason: "missing" } }
    controller.send(:handle_unverified_request)

    assert_equal "bad_state", controller.instance_variable_get(:@rejection_for_test)[:reason]

    OmniAuth.config.mock_auth[:apple] = OpenStruct.new(provider: "apple", uid: "uid")

    assert_equal "uid", controller.send(:mock_auth_from_test_mode).uid
    assert_equal "/sign/in/new", controller.send(:social_auth_failure_redirect_path)
  ensure
    OmniAuth.config.mock_auth.delete(:apple) if defined?(OmniAuth)
  end
end
