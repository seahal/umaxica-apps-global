# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthAppSignInPasskeyOptionsControllerCoverageTest < ActiveSupport::TestCase
  class Harness < Auth::App::Sign::In::Passkey::OptionsController
    attr_accessor :rendered, :committed

    def initialize; end

    def find_user_by_identifier(identifier)
      identifier
    end

    def verify_turnstile_stealth!
      true
    end

    def render_error(message, status)
      self.rendered = [message, status]
    end

    def retrieve_pt_for_checkpoint
      "pt"
    end

    def current_region_identifier
      "tokyo"
    end

    def render_session_limit_hard_reject(**kwargs)
      self.rendered = kwargs
    end

    def render(json:, status:)
      self.rendered = [json, status]
    end

    def auth_app_sign_in_session_path
      "/session"
    end

    def auth_app_sign_in_check_path(**kwargs)
      "/check?#{kwargs.to_query}"
    end

    def base_app_identity_url(**kwargs)
      "https://#{kwargs[:host]}/identity?ri=#{kwargs[:ri]}"
    end

    def base_authority_host
      "base.app.example"
    end

    def request
      Struct.new(:remote_ip).new("127.0.0.1")
    end
  end

  test "find_active_passkey_actor returns only an active client" do
    harness = Harness.new
    active = Object.new
    active.define_singleton_method(:active?) { true }
    inactive = Object.new
    inactive.define_singleton_method(:active?) { false }
    harness.define_singleton_method(:find_user_by_identifier) { |identifier| identifier == "ok" ? active : inactive }

    assert_equal active, harness.send(:find_active_passkey_actor, "ok")
    assert_nil harness.send(:find_active_passkey_actor, "no")
  end

  test "allow_passkey_sign_in? requires verified PII" do
    harness = Harness.new
    user = Object.new
    user.define_singleton_method(:has_verified_pii?) { true }
    passkey = Struct.new(:user, :user_id).new(user, 1)

    assert harness.send(:allow_passkey_sign_in?, passkey)

    user.define_singleton_method(:has_verified_pii?) { false }

    assert_equal false, harness.send(:allow_passkey_sign_in?, passkey)
  end

  test "perform_passkey_sign_in delegates to AuthenticationSessionCommitter" do
    harness = Harness.new
    user = Object.new
    passkey = Struct.new(:user).new(user)
    captured = []
    AuthenticationSessionCommitter.stub(:call, ->(**kwargs) { captured << kwargs }) do
      harness.send(:perform_passkey_sign_in, passkey)
    end

    assert_equal user, captured.first[:resource]
    assert_equal "passkey", captured.first[:auth_method]
  end

  test "login status helpers cover mfa session-limit and restricted success" do
    harness = Harness.new

    assert harness.send(:handle_domain_specific_login_status, { status: :mfa_required, redirect_path: "/mfa" })
    assert harness.send(
      :handle_domain_specific_login_status,
      { status: :session_limit_hard_reject, message: "limit", http_status: 403 },
    )
    assert_equal false, harness.send(:handle_domain_specific_login_status, { status: :ok })
    harness.send(:render_passkey_restricted_success, {})

    assert_equal "session_restricted", harness.rendered.first[:status]
    assert_includes harness.send(:passkey_checkpoint_redirect_url), "pt=pt"
    assert_includes harness.send(:passkey_default_redirect_url), "base.app.example"
    assert harness.send(:before_passkey_options_request!)
  end
end
