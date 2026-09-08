# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthAppOmniauthCallbacksBranchCoverageTest < ActiveSupport::TestCase
  test "failure ignores duplicate google callback after login" do
    c = Auth::App::Omniauth::OmniauthCallbacksController.new
    c.request = ActionDispatch::TestRequest.create("REQUEST_METHOD" => "GET")
    c.response = ActionDispatch::TestResponse.new
    session = { SocialAuth::SOCIAL_INTENT_SESSION_KEY => "login" }
    redirects = []
    c.define_singleton_method(:session) { session }
    c.define_singleton_method(:params) { ActionController::Parameters.new(message: "invalid_credentials", strategy: "google") }
    c.define_singleton_method(:logged_in?) { true }
    c.define_singleton_method(:redirect_to) { |path| redirects << path }
    c.define_singleton_method(:social_auth_success_redirect_path) { "/settings" }
    c.failure

    assert_equal ["/settings"], redirects
  end

  test "verified callback rejects unavailable provider" do
    c = Auth::App::Omniauth::OmniauthCallbacksController.new
    c.define_singleton_method(:params) { ActionController::Parameters.new(provider: "google") }
    c.define_singleton_method(:current_social_auth_intent) { "login" }
    c.define_singleton_method(:external_authentication_allowed?) { |**| false }
    c.define_singleton_method(:external_authentication_callback_available?) { |**| true }
    assert_raises(SocialAuth::ProviderError) { c.send(:verified_external_authentication_callback, Object.new) }
  end

  test "unexpected intent uses login handler" do
    c = Auth::App::Omniauth::OmniauthCallbacksController.new
    called = []
    c.define_singleton_method(:handle_login_intent) { |*args, **kwargs| called << [args, kwargs] }
    user = Struct.new(:id).new(1)
    c.send(:handle_successful_auth, user, "unexpected", "Google", :identity, existing_account: false, pt: "/return")

    assert_equal user, called.dig(0, 0, 0)
    assert_equal({ pt: "/return" }, called.dig(0, 1))
  end

  test "pending callback rejects unverified result" do
    c = Auth::App::Omniauth::OmniauthCallbacksController.new
    c.instance_variable_set(:@external_authentication_callback_result, Object.new)
    assert_raises(SocialAuth::ProviderError) { c.send(:handle_pending_social_sign_up_intent, "Google") }
  end

  test "social lock yields for incomplete identity" do
    c = Auth::App::Omniauth::OmniauthCallbacksController.new

    assert_equal :yielded, c.send(:with_social_sign_up_lock, Object.new) { :yielded }
  end

  test "social signup creation requires user and identity" do
    c = Auth::App::Omniauth::OmniauthCallbacksController.new
    assert_raises(SocialAuth::ProviderError) { c.send(:create_social_sign_up_flow!, nil, Object.new) }
    assert_raises(SocialAuth::ProviderError) { c.send(:create_social_sign_up_flow!, Object.new, nil) }
  end

  test "social identity binding fails closed on mismatches" do
    c = Auth::App::Omniauth::OmniauthCallbacksController.new
    cycle = Struct.new(:social_provider).new("google")
    user = Struct.new(:id).new(7)
    identities = [
      nil,
      Struct.new(:persisted?, :id, :user_id, :provider).new(false, nil, 7, "google"),
      Struct.new(:persisted?, :id, :user_id, :provider).new(true, 1, 8, "google"),
      Struct.new(:persisted?, :id, :user_id, :provider).new(true, 1, 7, "apple"),
    ]

    identities.each { |identity| assert_raises(SocialAuth::ProviderError) { c.send(:bind_social_sign_up_flow!, cycle, user, identity) } }
  end

  test "pending session limit and nonhash login result are handled" do
    c = Auth::App::Omniauth::OmniauthCallbacksController.new
    redirects = []
    c.define_singleton_method(:redirect_to) { |path| redirects << path }
    c.define_singleton_method(:auth_app_sign_in_path) { "/sign/in" }
    c.define_singleton_method(:sign_in_result_from_session_result) { |*_args, **_kwargs|
      Struct.new(:status, :redirect_to).new(:session_limit_pending, "/sessions")
    }
    c.send(:handle_login_failure, { status: :session_limit_pending }, "Google", nil)

    assert_equal ["/sessions"], redirects
    assert_equal({ result_class: "String" }, c.send(:social_login_result_log_payload, "not-a-hash"))
  end
end
