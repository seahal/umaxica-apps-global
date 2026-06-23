# typed: false
# frozen_string_literal: true

require "test_helper"

module Authentication
  class LogoutableTest < ActiveSupport::TestCase
    class Token
      attr_reader :revoked_with

      def present?
        true
      end

      def revoked?
        false
      end

      def revoke!
        @revoked_with = :revoke!
      end
    end

    class Harness
      include AuthenticationLogoutable

      attr_reader :session, :cookies, :resource, :token, :other_tokens

      def initialize(other_tokens: [])
        @session = {
          "_csrf_token" => "csrf",
          "passkey_challenges" => { "challenge" => "value" },
          "pending_mfa" => { "user_id" => 1 },
        }
        @cookies = {
          AuthenticationBase::ACCESS_COOKIE_KEY => "access-token",
          AuthenticationBase::REFRESH_COOKIE_KEY => "refresh-token",
        }
        @resource = Object.new
        @token = Token.new
        @other_tokens = other_tokens
        @audit_events = []
      end

      def current_resource = resource

      def current_session = token

      def current_session_public_id = "session-public-id"

      def token_class = ClientToken

      def clear_auth_cookies!
        cookies.delete(AuthenticationBase::ACCESS_COOKIE_KEY)
        cookies.delete(AuthenticationBase::REFRESH_COOKIE_KEY)
      end

      def reset_session
        session.clear
      end

      def record_audit(event, resource:)
        @audit_events << [event, resource]
      end

      def audit_events = @audit_events

      public :logout_current_session!
      public :logout_all_sessions_for!
    end

    class FailingLogoutHarness < Harness
      class BoomError < StandardError; end

      # Simulate an audit-write failure (e.g. chronicle DB unreachable)
      # after the token has been revoked. The ensure block must still
      # clear cookies and the Rails session.
      def record_audit(_event, resource:)
        raise BoomError, "audit write failed"
      end
    end

    class FailingCurrentResourceHarness < Harness
      def current_resource
        raise StandardError, "resource lookup failed"
      end
    end

    class FailingCurrentSessionHarness < Harness
      def current_session
        raise StandardError, "session lookup failed"
      end
    end

    test "logout_current_session revokes token clears auth cookies and purges rails session" do
      harness = Harness.new
      Actor.install_context!(
        actor: harness.resource, actor_type: :client, authn: Actor::Authentication.new(
          login_public_id: "session-public-id",
          actor_type: :client,
        ),
      )

      harness.logout_current_session!(reason: "test_logout")

      assert_equal :revoke!, harness.token.revoked_with
      assert_empty harness.session
      assert_nil harness.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
      assert_nil harness.cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
      assert_same Unauthenticated.instance, Actor.actor
      assert_equal [[AuthenticationBase::AUDIT_EVENTS[:logout_current_session], harness.resource]],
                   harness.audit_events
    ensure
      Actor.reset
    end

    test "logout_all_sessions records distinct all sessions audit and clears local state" do
      harness = Harness.new

      AuthenticationLogoutAllSessions.stub(:call, ->(**) { true }) do
        harness.logout_all_sessions_for!(resource: harness.resource, reason: "test_logout_all")
      end

      assert_empty harness.session
      assert_nil harness.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
      assert_nil harness.cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
      assert_equal [[AuthenticationBase::AUDIT_EVENTS[:logout_all_sessions], harness.resource]],
                   harness.audit_events
    end

    test "base log_out delegates to logoutable concern" do
      assert_includes Sign::App::ApplicationController.private_instance_methods, :logout_current_session!
    end

    # ------------------------------------------------------------------
    # Regression coverage for "ordinary logout must not revoke other
    # sessions" (S-0) and "logout must clear local state even on failure"
    # (S-2). If either regresses, these tests fail loudly.
    # ------------------------------------------------------------------
    test "Oidc::SingleLogoutService is intentionally absent" do
      # The misleadingly-named Oidc::SingleLogoutService used to live at
      # `app/services/oidc/single_logout_service.rb` and revoked every
      # active token for the actor. It was deleted because (a) its name
      # promised OIDC SLO-protocol semantics while doing something else,
      # and (b) its only correct use case is already covered by
      # AuthenticationLogoutAllSessions. If this guard fails it means
      # someone re-added the class -- keep the deletion and use
      # LogoutAllSessions from a dedicated endpoint instead.
      assert_not defined?(Oidc::SingleLogoutService),
                 "Oidc::SingleLogoutService must remain deleted. See " \
                 "adr/logout-primitive-and-composition.md."
    end

    test "logout_current_session does NOT invoke logout_all_sessions_for!" do
      harness = Harness.new

      called = false
      AuthenticationLogoutAllSessions.stub(:call, ->(**) { called = true }) do
        harness.logout_current_session!(reason: "test_logout")
      end

      assert_not called,
                 "Ordinary logout must not fan out to LogoutAllSessions. " \
                 "Multi-device logout requires an explicit endpoint."
    end

    test "logout resolution can fall back to a refresh cookie record" do
      token = Token.new
      harness = Harness.new
      harness.cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = "refresh-session"
      harness.define_singleton_method(:current_session) { nil }
      harness.define_singleton_method(:current_session_public_id) { nil }
      harness.define_singleton_method(:find_refresh_token_record) { |refresh_public_id|
        (refresh_public_id == "refresh-session") ? token : nil
      }
      harness.define_singleton_method(:token_class) do
        Class.new do
          def self.parse_refresh_token(refresh_plain)
            ["refresh-session", refresh_plain]
          end
        end
      end

      assert_equal token, harness.send(:session_token_from_refresh_cookie_for_logout)
    end

    test "logout_current_session clears cookies and session even if revoke raises" do
      harness = Harness.new

      assert_raises(StandardError) do
        AuthenticationLogoutCurrentSession.stub(:call, ->(**) { raise StandardError, "revoke failed" }) do
          harness.logout_current_session!(reason: "test_logout")
        end
      end

      assert_empty harness.session,
                   "Rails session must be reset in ensure even on failure"
      assert_nil harness.cookies[AuthenticationBase::ACCESS_COOKIE_KEY],
                 "access cookie must be cleared in ensure even on failure"
      assert_nil harness.cookies[AuthenticationBase::REFRESH_COOKIE_KEY],
                 "refresh cookie must be cleared in ensure even on failure"
    end

    test "logout_current_session clears cookies and session even if audit raises" do
      harness = FailingLogoutHarness.new

      assert_raises(FailingLogoutHarness::BoomError) do
        harness.logout_current_session!(reason: "test_logout")
      end

      assert_empty harness.session,
                   "Rails session must be reset in ensure even on audit failure"
      assert_nil harness.cookies[AuthenticationBase::ACCESS_COOKIE_KEY],
                 "access cookie must be cleared in ensure even on audit failure"
      assert_nil harness.cookies[AuthenticationBase::REFRESH_COOKIE_KEY],
                 "refresh cookie must be cleared in ensure even on audit failure"
    end

    test "logout_current_session fails closed but clears local state when resource resolution raises" do
      harness = FailingCurrentResourceHarness.new

      error =
        assert_raises(AuthenticationLogoutable::ResolutionError) do
          harness.logout_current_session!(reason: "test_logout")
        end

      assert_match "Logout current_resource resolution failed", error.message
      assert_equal "resource lookup failed", error.cause.message
      assert_empty harness.session,
                   "Rails session must be reset in ensure even on resource resolution failure"
      assert_nil harness.cookies[AuthenticationBase::ACCESS_COOKIE_KEY],
                 "access cookie must be cleared in ensure even on resource resolution failure"
      assert_nil harness.cookies[AuthenticationBase::REFRESH_COOKIE_KEY],
                 "refresh cookie must be cleared in ensure even on resource resolution failure"
    end

    test "logout_current_session fails closed but clears local state when session resolution raises" do
      harness = FailingCurrentSessionHarness.new

      error =
        assert_raises(AuthenticationLogoutable::ResolutionError) do
          harness.logout_current_session!(reason: "test_logout")
        end

      assert_match "Logout current_session resolution failed", error.message
      assert_equal "session lookup failed", error.cause.message
      assert_empty harness.session,
                   "Rails session must be reset in ensure even on session resolution failure"
      assert_nil harness.cookies[AuthenticationBase::ACCESS_COOKIE_KEY],
                 "access cookie must be cleared in ensure even on session resolution failure"
      assert_nil harness.cookies[AuthenticationBase::REFRESH_COOKIE_KEY],
                 "refresh cookie must be cleared in ensure even on session resolution failure"
    end
  end
end
