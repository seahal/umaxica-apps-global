# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Auth::OmniauthCallbacksControllerTest < ActiveSupport::TestCase
  test "callback route accepts google GET only" do
    host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    route = Rails.application.routes.recognize_path(
      "http://#{host}/auth/google_org/callback",
      method: :get,
    )

    assert_equal "sign/org/auth/omniauth_callbacks", route[:controller]
    assert_equal "omniauth", route[:action]
    assert_equal "google_org", route[:provider]

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("http://#{host}/auth/google_org/callback", method: :post)
    end
  end

  test "direct org omniauth callback branches" do
    controller = Sign::Org::Auth::OmniauthCallbacksController.new
    session_hash = {}
    redirects = []
    hard_rejects = []

    request = ActionDispatch::TestRequest.create("REQUEST_METHOD" => "GET", "REMOTE_ADDR" => "127.0.0.1")
    controller.request = request
    controller.response = ActionDispatch::TestResponse.new
    controller.define_singleton_method(:session) { session_hash }
    controller.define_singleton_method(:params) do |*|
      ActionController::Parameters.new(ri: "jp", provider: "google_org", message: "denied")
    end
    controller.define_singleton_method(:redirect_to) { |*args, **kwargs| redirects << [args, kwargs] }
    controller.define_singleton_method(:render_session_limit_hard_reject) { |**kwargs| hard_rejects << kwargs }
    controller.define_singleton_method(:new_sign_org_sign_in_path) { "/org/in/new" }
    controller.define_singleton_method(:sign_org_in_session_path) { "/org/in/session" }
    controller.define_singleton_method(:sign_org_in_checkpoint_path) { |ri: nil| "/org/in/checkpoint?ri=#{ri}" }
    controller.define_singleton_method(:sign_org_dashboard_path) { |ri: nil, pt: nil|
      "/org/dashboard?ri=#{ri}#{pt ? "&pt=#{pt}" : ""}"
    }
    controller.define_singleton_method(:sign_org_root_path) { |ri: nil| "/org?ri=#{ri}" }
    controller.define_singleton_method(:sign_org_configuration_path) { "/org/configuration" }
    controller.define_singleton_method(:clear_social_auth_intent!) { @cleared_for_test = true }
    controller.define_singleton_method(:issue_bulletin!) { @issue_bulletin_for_test }
    controller.define_singleton_method(:log_in) { |*| @login_result_for_test }

    auth = {
      "provider" => "google_org",
      "uid" => "google-org-uid",
      "credentials" => { "token" => "token", "expires_at" => 1.week.from_now.to_i },
      "info" => { "email" => " STAFF@example.COM " },
    }
    auth.define_singleton_method(:provider) { self["provider"] }

    controller.send(:handle_missing_auth)

    assert_match "/org/in/new", redirects.last.first.first

    assert_nil controller.send(:find_active_staff_by_google_identity, { "provider" => "google_org" })

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

    assert_match %r{/session}, redirects.last.first.first

    controller.send(:handle_login_result, { status: :unknown }, "Google org")

    assert_match "/org/in/new", redirects.last.first.first

    controller.send(:handle_login_result, { status: :success, restricted: true }, "Google org")

    assert_match %r{/session}, redirects.last.first.first

    controller.instance_variable_set(:@issue_bulletin_for_test, true)
    controller.send(:handle_login_result, true, "Google org")

    assert_match %r{/dashboard\?}, redirects.last.first.first

    controller.instance_variable_set(:@issue_bulletin_for_test, false)
    controller.send(:handle_login_result, true, "Google org")

    assert_match %r{/dashboard\?}, redirects.last.first.first

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
    auth = OpenStruct.new(
      provider: "google_org",
      uid: "google-org-direct",
      credentials: OpenStruct.new(token: "token", expires_at: 1.week.from_now.to_i),
    )
    request.env["omniauth.auth"] = auth
    controller.request = request
    controller.response = ActionDispatch::TestResponse.new

    staff = OpenStruct.new(id: 22, login_allowed?: true)
    controller.define_singleton_method(:params) do |*|
      ActionController::Parameters.new(provider: "google_org")
    end
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
    controller.define_singleton_method(:google_signin_enabled?) { true }

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

  test "direct org omniauth callback does not proceed when google signin flag is off" do
    controller = Sign::Org::Auth::OmniauthCallbacksController.new
    redirects = []
    request = ActionDispatch::TestRequest.create("REQUEST_METHOD" => "GET")
    auth = OpenStruct.new(provider: "google_org", uid: "disabled-google-org")
    controller.request = request
    controller.response = ActionDispatch::TestResponse.new

    controller.define_singleton_method(:redirect_to) { |*args, **kwargs| redirects << [args, kwargs] }
    controller.define_singleton_method(:new_sign_org_sign_in_path) { "/org/in/new" }
    controller.define_singleton_method(:clear_social_auth_intent!) { @cleared_for_test = true }
    controller.define_singleton_method(:google_signin_enabled?) { false }
    controller.define_singleton_method(:validate_social_auth_state!) { raise "state must not be validated" }
    controller.define_singleton_method(:find_staff_from_auth) { raise "staff lookup must not run" }
    controller.define_singleton_method(:login_and_redirect) { raise "login must not run" }

    controller.send(:handle_omniauth_callback, auth)

    assert controller.instance_variable_get(:@cleared_for_test)
    assert_match "/org/in/new", redirects.last.first.first
  end

  test "login_and_redirect records org social audit context" do
    controller = Sign::Org::Auth::OmniauthCallbacksController.new
    staff = OpenStruct.new(id: 22, login_allowed?: true)
    auth = OpenStruct.new(provider: "google_org")

    controller.define_singleton_method(:log_in) do |resource, **kwargs|
      @login_resource_for_test = resource
      @login_kwargs_for_test = kwargs
      { status: :success }
    end
    controller.define_singleton_method(:handle_login_result) do |result, provider_name|
      @login_result_for_test = result
      @provider_name_for_test = provider_name
    end

    controller.send(:login_and_redirect, staff, auth)

    assert_equal staff, controller.instance_variable_get(:@login_resource_for_test)
    assert controller.instance_variable_get(:@login_kwargs_for_test)[:record_login_audit]
    assert_equal(
      { auth_method: "social", provider: "google" },
      controller.instance_variable_get(:@login_kwargs_for_test)[:audit_context],
    )
    assert_equal({ status: :success }, controller.instance_variable_get(:@login_result_for_test))
    assert_equal "Google", controller.instance_variable_get(:@provider_name_for_test)
  end

  test "find_active_staff_by_google_identity returns active staff for linked identity" do
    controller = Sign::Org::Auth::OmniauthCallbacksController.new
    staff = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    OperatorGoogleIdentity.create!(
      staff: staff,
      uid: "google-staff-uid",
      provider: "google_org",
      token: "old-token",
      token_expires_at: 1.week.from_now.to_i,
    )
    auth = google_auth(uid: "google-staff-uid", token: "new-token")

    assert_equal staff, controller.send(:find_active_staff_by_google_identity, auth)
    assert_equal "new-token", staff.reload.operator_google_identity.token
  end

  test "find_active_staff_by_google_identity rejects suspended active-status staff" do
    controller = Sign::Org::Auth::OmniauthCallbacksController.new
    staff = Operator.create!(
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
      deactivated_at: Time.current,
    )
    OperatorGoogleIdentity.create!(
      staff: staff,
      uid: "suspended-google-staff-uid",
      provider: "google_org",
      token: "token",
      token_expires_at: 1.week.from_now.to_i,
    )

    assert_nil controller.send(:find_active_staff_by_google_identity, google_auth(uid: "suspended-google-staff-uid"))
  end

  test "find_active_staff_by_google_identity links current staff by provider uid" do
    controller = Sign::Org::Auth::OmniauthCallbacksController.new
    staff = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    controller.define_singleton_method(:social_auth_user) { staff }
    auth = google_auth(uid: "google-link-staff-uid")

    assert_equal staff,
                 controller.send(:find_active_staff_by_google_identity, auth, intent: "link")
    assert_equal "google-link-staff-uid", staff.reload.operator_google_identity.uid
  end

  test "find_active_staff_by_google_identity rejects unlinked provider uid for login intent" do
    controller = Sign::Org::Auth::OmniauthCallbacksController.new

    assert_no_difference ["Operator.count", "OperatorGoogleIdentity.count"] do
      assert_nil controller.send(:find_active_staff_by_google_identity, google_auth(uid: "unlinked-google-uid"))
    end
  end

  test "temporary signup provisions allowlisted staff by provider uid" do
    controller = Sign::Org::Auth::OmniauthCallbacksController.new
    auth = google_auth(uid: "allowlisted-signup-uid")
    auth.info = OpenStruct.new(email: "Allowed@Example.Test")

    with_env("ORG_GOOGLE_SIGNUP_ALLOWLIST" => "allowed@example.test") do
      assert_difference ["Operator.count", "OperatorGoogleIdentity.count"], 1 do
        staff = controller.send(:find_active_staff_by_google_identity, auth, entry: "sign_up")

        assert_equal OperatorStatus::ACTIVE, staff.status_id
        assert_equal "allowlisted-signup-uid", staff.operator_google_identity.uid
      end
    end
  end

  test "temporary signup delegates provisioning to org operator provisioner" do
    controller = Sign::Org::Auth::OmniauthCallbacksController.new
    auth = google_auth(uid: "delegated-signup-uid")
    staff = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    calls = []

    Sign::Social::OrgOperatorProvisioner.stub(:call, ->(auth_arg, identity:) {
      calls << [auth_arg, identity]
      staff
    }) do
      assert_equal staff, controller.send(:find_active_staff_by_google_identity, auth, entry: "sign_up")
    end

    assert_equal 1, calls.size
    assert_equal auth, calls.first.first
    assert_nil calls.first.last
  end

  test "temporary signup rejects unallowlisted staff without creating records" do
    controller = Sign::Org::Auth::OmniauthCallbacksController.new
    auth = google_auth(uid: "unallowlisted-signup-uid")
    auth.info = OpenStruct.new(email: "blocked@example.test")

    with_env("ORG_GOOGLE_SIGNUP_ALLOWLIST" => "allowed@example.test") do
      assert_no_difference ["Operator.count", "OperatorGoogleIdentity.count"] do
        assert_nil controller.send(:find_active_staff_by_google_identity, auth, entry: "sign_up")
      end
    end
  end

  test "temporary signup duplicate uid does not create records twice" do
    controller = Sign::Org::Auth::OmniauthCallbacksController.new
    staff = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    OperatorGoogleIdentity.create!(
      staff: staff,
      uid: "duplicate-signup-uid",
      provider: "google_org",
      token: "old-token",
      token_expires_at: 1.week.from_now.to_i,
    )
    auth = google_auth(uid: "duplicate-signup-uid", token: "new-token")
    auth.info = OpenStruct.new(email: "allowed@example.test")

    with_env("ORG_GOOGLE_SIGNUP_ALLOWLIST" => "allowed@example.test") do
      assert_no_difference ["Operator.count", "OperatorGoogleIdentity.count"] do
        assert_equal staff, controller.send(:find_active_staff_by_google_identity, auth, entry: "sign_up")
      end
    end
    assert_equal "new-token", staff.reload.operator_google_identity.token
  end

  test "find_active_staff_by_google_identity rejects missing and inactive staff identity" do
    controller = Sign::Org::Auth::OmniauthCallbacksController.new
    staff = Operator.create!(status_id: OperatorStatus::NOTHING, visibility_id: OperatorVisibility::STAFF)
    OperatorGoogleIdentity.create!(
      staff: staff,
      uid: "inactive-google-staff-uid",
      provider: "google_org",
      token: "token",
      token_expires_at: 1.week.from_now.to_i,
    )

    assert_nil controller.send(:find_active_staff_by_google_identity, google_auth(uid: "missing-google-staff-uid"))
    assert_nil controller.send(:find_active_staff_by_google_identity, google_auth(uid: "inactive-google-staff-uid"))
  end

  private

  def google_auth(uid:, token: "token")
    OpenStruct.new(
      provider: "google_org",
      uid: uid,
      credentials: OpenStruct.new(token: token, refresh_token: "refresh-token", expires_at: 1.week.from_now.to_i),
    )
  end

  def with_env(values)
    original = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    original.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
