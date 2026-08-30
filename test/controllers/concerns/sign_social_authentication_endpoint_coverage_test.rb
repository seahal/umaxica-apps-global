# typed: false
# frozen_string_literal: true

require "test_helper"

class SignSocialAuthenticationEndpointCoverageTest < ActiveSupport::TestCase
  class Harness
    include SignSocialAuthenticationEndpoint

    attr_accessor :params_hash, :redirect_args, :request_obj, :session_hash, :flash_hash

    def initialize
      @params_hash = {}
      @session_hash = {}
      @flash_hash = {}
      @request_obj = Object.new
      @request_obj.define_singleton_method(:parameters) { {} }
      @request_obj.define_singleton_method(:referer) { "https://example.test/not-sign-up" }
    end

    def params = ActionController::Parameters.new(@params_hash)

    def request = @request_obj

    def session = @session_hash

    def flash = @flash_hash

    def redirect_to(*args, **kwargs)
      @redirect_args = [args, kwargs]
    end

    def auth_app_sign_in_path
      "/sign-in"
    end

    def auth_app_sign_up_path
      "/sign-up"
    end

    def omniauth_authorize_path(provider)
      "/auth/#{provider}"
    end

    def auth_app_settings_apple_path(**)
      "/settings/apple"
    end

    def auth_app_settings_google_path(**)
      "/settings/google"
    end

    def logged_in?
      false
    end

    def current_resource
      nil
    end
  end

  test "continue_social_authentication rejects an unsupported provider" do
    harness = Harness.new

    harness.send(:continue_social_authentication, provider: "unknown")

    assert_equal ["/sign-in"], harness.redirect_args.first
    assert_equal I18n.t("sign.app.social.sessions.invalid_provider"), harness.redirect_args.last[:alert]
  end

  test "social_auth_entry classifies signup referers and invalid URIs" do
    harness = Harness.new
    harness.request_obj.define_singleton_method(:parameters) { { "entry" => "auth_up" } }

    assert_equal "auth_up", harness.send(:social_auth_entry)

    harness.request_obj.define_singleton_method(:parameters) { {} }
    harness.request_obj.define_singleton_method(:referer) { "https://example.test/sign-up" }

    assert_equal "auth_up", harness.send(:social_auth_entry)

    harness.request_obj.define_singleton_method(:referer) { "https://example.test/sign-in" }

    assert_equal "sign_in", harness.send(:social_auth_entry)

    harness.request_obj.define_singleton_method(:referer) { "http://[bad" }

    assert_equal "sign_in", harness.send(:social_auth_entry)
  end

  test "unlink and link settings paths follow the provider" do
    harness = Harness.new

    assert_equal "/settings/apple", harness.send(:social_unlink_settings_path, "apple")
    assert_equal "/settings/google", harness.send(:social_unlink_settings_path, "google")
    assert_equal "/settings/apple", harness.send(:social_link_settings_path, "apple")
    harness.define_singleton_method(:social_provider) { "apple" }

    assert_equal "/settings/apple", harness.send(:social_auth_failure_redirect_path)
    assert_equal "anonymous", harness.send(:social_login_actor_ref)
    assert_equal "google", harness.send(:social_entry_method, "GOOGLE")
    assert_equal "social_unlink", harness.send(:verification_scope)
  end

  test "require_social_link_step_up! skips when the intent is not a logged-in link" do
    harness = Harness.new
    harness.params_hash = { intent: "login", provider: "google" }

    assert harness.send(:require_social_link_step_up!)
  end

  test "require_social_link_step_up! redirects a logged-in link without step-up" do
    harness = Harness.new
    harness.params_hash = { intent: "link", provider: "google", ri: "tokyo" }
    harness.define_singleton_method(:logged_in?) { true }
    harness.define_singleton_method(:current_resource) { Client.new }
    harness.define_singleton_method(:step_up_satisfied?) { |**| false }
    harness.define_singleton_method(:encoded_relative_pt) { |_path| "pt" }
    harness.define_singleton_method(:actor_verification_path) { |**kwargs| "/verify?#{kwargs.to_query}" }

    result = harness.send(:require_social_link_step_up!)

    assert_equal false, result
    assert_equal I18n.t("auth.step_up.required"), harness.flash_hash[:alert]
    assert_equal :see_other, harness.redirect_args.last[:status]
  end

  test "disconnect_social_authentication redirects when turnstile fails" do
    harness = Harness.new
    harness.define_singleton_method(:cloudflare_turnstile_stealth_validation) { { "success" => false } }
    harness.define_singleton_method(:t) { |key| I18n.t(key) }

    harness.send(:disconnect_social_authentication, provider: "google")

    assert_equal :see_other, harness.redirect_args.last[:status]
    assert_equal I18n.t("turnstile_error"), harness.redirect_args.last[:alert]
  end
end
