# typed: false
# frozen_string_literal: true

require "test_helper"

class Verification::BaseBootstrapReturnPathTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  Request =
    Struct.new(:parameters, :host, :fullpath, :request_id, keyword_init: true) do
      def parameters
        self[:parameters] || {}
      end
    end

  TokenStub = Struct.new(:public_id)

  module Sign
    module App
      class BootstrapHarness
        class << self
          def before_action(*) = nil

          def helper_method(*) = nil
        end

        include Common::Redirect
        include Verification::Base

        attr_accessor :rt_param, :session_token, :verification_surface_override

        def request
          Request.new(
            parameters: { "pt" => rt_param.to_s },
            host: "id.app.localhost",
            fullpath: "/configuration/passkeys",
            request_id: "req-1",
          )
        end

        def current_session_token = session_token
      end
    end

    module Com
      class BootstrapHarness < Sign::App::BootstrapHarness
      end
    end

    module Org
      class BootstrapHarness < Sign::App::BootstrapHarness
      end
    end
  end

  test "returns default when pt is missing" do
    h = Sign::App::BootstrapHarness.new
    h.rt_param = nil
    h.session_token = TokenStub.new("nonce-1")

    assert_equal "/default", h.send(:bootstrap_return_path, "/default")
  end

  test "accepts a signed token whose surface and session match" do
    token = signed_return_target(
      return_to: "/configuration/passkeys/123",
      flow: "step_up.bootstrap",
      surface: "app",
      session_nonce: "nonce-1",
    )
    h = Sign::App::BootstrapHarness.new
    h.rt_param = token
    h.session_token = TokenStub.new("nonce-1")

    assert_equal "/configuration/passkeys/123", h.send(:bootstrap_return_path, "/default")
  end

  test "rejects a signed token whose surface does not match the harness class" do
    token = signed_return_target(
      return_to: "/configuration/passkeys/123",
      flow: "step_up.bootstrap",
      surface: "com",
      session_nonce: "nonce-1",
    )
    h = Sign::App::BootstrapHarness.new
    h.rt_param = token
    h.session_token = TokenStub.new("nonce-1")

    assert_equal "/default", h.send(:bootstrap_return_path, "/default")
  end

  test "rejects a signed token whose session nonce does not match" do
    token = signed_return_target(
      return_to: "/configuration/passkeys/123",
      flow: "step_up.bootstrap",
      surface: "app",
      session_nonce: "issued-for-other-session",
    )
    h = Sign::App::BootstrapHarness.new
    h.rt_param = token
    h.session_token = TokenStub.new("current-session")

    assert_equal "/default", h.send(:bootstrap_return_path, "/default")
  end

  test "rejects legacy Base64 path when pt is not a signed token" do
    legacy = Base64.urlsafe_encode64("/configuration/passkeys/legacy")
    h = Sign::App::BootstrapHarness.new
    h.rt_param = legacy
    h.session_token = TokenStub.new("nonce-1")

    assert_equal "/default", h.send(:bootstrap_return_path, "/default")
  end

  test "returns default for legacy Base64 input" do
    legacy = Base64.urlsafe_encode64("https://attacker.example.com/path")
    h = Sign::App::BootstrapHarness.new
    h.rt_param = legacy
    h.session_token = TokenStub.new("nonce-1")

    assert_equal "/default", h.send(:bootstrap_return_path, "/default")
  end

  test "returns default when pt cannot be decoded by either path" do
    h = Sign::App::BootstrapHarness.new
    h.rt_param = "not-base64!?!?garbage"
    h.session_token = TokenStub.new("nonce-1")

    assert_equal "/default", h.send(:bootstrap_return_path, "/default")
  end

  test "infers surface = com from the harness class name" do
    token = signed_return_target(
      return_to: "/configuration/passkeys/com-route",
      flow: "step_up.bootstrap",
      surface: "com",
      session_nonce: "nonce-1",
    )
    h = Sign::Com::BootstrapHarness.new
    h.rt_param = token
    h.session_token = TokenStub.new("nonce-1")

    assert_equal "/configuration/passkeys/com-route", h.send(:bootstrap_return_path, "/default")
  end

  test "infers surface = org from the harness class name" do
    token = signed_return_target(
      return_to: "/configuration/passkeys/org-route",
      flow: "step_up.bootstrap",
      surface: "org",
      session_nonce: "nonce-1",
    )
    h = Sign::Org::BootstrapHarness.new
    h.rt_param = token
    h.session_token = TokenStub.new("nonce-1")

    assert_equal "/configuration/passkeys/org-route", h.send(:bootstrap_return_path, "/default")
  end

  test "expired signed token returns default" do
    token = signed_return_target(
      return_to: "/configuration/passkeys/123",
      flow: "step_up.bootstrap",
      surface: "app",
      session_nonce: "nonce-1",
      expires_in: 1.second,
    )
    h = Sign::App::BootstrapHarness.new
    h.rt_param = token
    h.session_token = TokenStub.new("nonce-1")

    travel 5.seconds do
      assert_equal "/default", h.send(:bootstrap_return_path, "/default")
    end
  end

  private

  def signed_return_target(return_to:, flow:, surface:, session_nonce:, expires_in: 15.minutes)
    return_target_token_harness.issue(
      return_to: return_to,
      flow: flow,
      surface: surface,
      session_nonce: session_nonce,
      expires_in: expires_in,
    )
  end

  def return_target_token_harness
    @return_target_token_harness ||= Class.new do
      include ::Redirects::SignedTargetSupport

      def issue(return_to:, flow:, surface:, session_nonce:, expires_in:)
        path = signed_target_internal_path(return_to)
        claims = signed_target_claims(flow: flow, surface: surface, session_nonce: session_nonce)
        issue_signed_target_token(
          payload: claims.merge("pt" => path),
          purpose: Verification::Base::STEP_UP_PATH_TARGET_TOKEN_PURPOSE,
          salt: Verification::Base::STEP_UP_PATH_TARGET_TOKEN_SALT,
          expires_in: expires_in,
        )
      end
    end.new
  end
end
