# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthComSignInPasskeyOptionsControllerCoverageTest < ActiveSupport::TestCase
  class Harness < Auth::Com::Sign::In::Passkey::OptionsController
    def initialize
      super
      @rendered = nil
    end

    attr_accessor :rendered, :established

    def find_user_by_identifier(identifier)
      identifier
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

    def establish_signed_in_session!(visitor, **)
      self.established = visitor
    end

    def render_session_limit_hard_reject(**kwargs)
      self.rendered = kwargs
    end

    def render(json:, status:)
      self.rendered = [json, status]
    end

    def auth_com_sign_in_session_path
      "/sign-in/session"
    end

    def auth_com_sign_in_check_path(**kwargs)
      "/sign-in/check?#{kwargs.to_query}"
    end

    def base_com_identity_url(**kwargs)
      "https://#{kwargs[:host]}/identity?ri=#{kwargs[:ri]}"
    end

    def base_authority_host
      "base.com.example"
    end

    def request
      Struct.new(:remote_ip).new("127.0.0.1")
    end
  end

  test "identity mapping helpers resolve visitor records" do
    harness = Harness.new
    email = Struct.new(:visitor).new(:visitor_from_email)
    telephone = Struct.new(:visitor).new(:visitor_from_telephone)

    assert_equal VisitorEmail, harness.send(:identity_email_model)
    assert_equal VisitorTelephone, harness.send(:identity_telephone_model)
    assert_equal :visitor_from_email, harness.send(:identity_from_email_record, email)
    assert_equal :visitor_from_telephone, harness.send(:identity_from_telephone_record, telephone)
  end

  test "find_active_passkey_actor returns only an active visitor" do
    harness = Harness.new
    active = Object.new
    active.define_singleton_method(:active?) { true }
    inactive = Object.new
    inactive.define_singleton_method(:active?) { false }
    harness.define_singleton_method(:find_user_by_identifier) { |identifier| (identifier == "ok") ? active : inactive }

    assert_equal active, harness.send(:find_active_passkey_actor, "ok")
    assert_nil harness.send(:find_active_passkey_actor, "no")
  end

  test "allow_passkey_sign_in? requires verified PII" do
    harness = Harness.new
    visitor = Object.new
    visitor.define_singleton_method(:has_verified_pii?) { true }
    passkey = Struct.new(:visitor, :visitor_id).new(visitor, 1)

    assert harness.send(:allow_passkey_sign_in?, passkey)

    visitor.define_singleton_method(:has_verified_pii?) { false }

    assert_not harness.send(:allow_passkey_sign_in?, passkey)
    assert_equal ["errors.webauthn.credential_not_found", :unauthorized], harness.rendered
  end

  test "perform_passkey_sign_in establishes a visitor session" do
    harness = Harness.new
    visitor = Object.new
    passkey = Struct.new(:visitor).new(visitor)

    harness.send(:perform_passkey_sign_in, passkey)

    assert_equal visitor, harness.established
  end

  test "handle_domain_specific_login_status covers mfa and session-limit results" do
    harness = Harness.new

    assert harness.send(:handle_domain_specific_login_status, { status: :mfa_required, redirect_path: "/mfa" })
    assert_equal [{ status: "mfa_required", redirect_url: "/mfa" }, :ok], harness.rendered
    assert harness.send(
      :handle_domain_specific_login_status,
      { status: :session_limit_hard_reject, message: "limit", http_status: 403 },
    )
    assert_not harness.send(:handle_domain_specific_login_status, { status: :ok })
  end

  test "restricted success and redirect helpers use the com identity host" do
    harness = Harness.new

    harness.send(:render_passkey_restricted_success, {})
    json, status = harness.rendered

    assert_equal "session_restricted", json[:status]
    assert_equal :ok, status
    assert_includes harness.send(:passkey_checkpoint_redirect_url), "pt=pt"
    assert_includes harness.send(:passkey_default_redirect_url), "base.com.example"
  end
end
