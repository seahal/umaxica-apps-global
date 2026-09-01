# typed: false
# frozen_string_literal: true

require "test_helper"

# Cancelling a session-limit prompt sends the visitor back to the sign-in page of
# the surface they were cancelling on, never another surface's. When the sign-in
# was itself started by an OIDC client the pending login challenge has to survive
# the cancellation, or the relying party's request is silently dropped and the
# visitor lands on a bare sign-in page that no longer completes their delegation.
class SessionLimitCancellationSignInPathsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def harness_for(controller_class, session_hash)
    Class.new(controller_class) do
      attr_accessor :session_hash

      def session = session_hash

      def current_region_identifier = "jp"

      def invoke(name, ...) = send(name, ...)
    end.new.tap do |harness|
      harness.session_hash = session_hash
      harness.request = ActionDispatch::TestRequest.create
    end
  end

  {
    "com" => Auth::Com::Sign::In::Session::CancellationsController,
    "org" => Auth::Org::Sign::In::Session::CancellationsController,
  }.each do |surface, controller_class|
    test "cancelling a plain #{surface} sign-in returns to the #{surface} sign-in page" do
      path = harness_for(controller_class, {}).invoke(:session_limit_sign_in_path)

      # The surfaces are separated by host rather than by path prefix, so this
      # pins the path each surface's own helper produces and the absence of a
      # challenge that was never started.
      assert_equal "/sign/in?ri=jp", path
      assert_not_includes path, "login_challenge"
    end

    test "cancelling an OIDC-started #{surface} sign-in carries the login challenge back" do
      session = { oidc_authorization_login_challenge: "challenge-token" }

      path = harness_for(controller_class, session).invoke(:session_limit_sign_in_path)

      assert_includes path, "login_challenge=challenge-token"
      assert_includes path, "ri=jp"
    end
  end
end
