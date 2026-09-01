# typed: false
# frozen_string_literal: true

require "test_helper"

# A principal whose sign-in is parked at the session limit may only reach the
# actions its controller allowlists; everything else is sent to the session
# management screen. The guard defaults to an empty allowlist so a controller
# that includes it without declaring one parks every action rather than leaking
# one through.
class SessionLimitPendingGuardTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness < ActionController::Base
    include SessionLimitPendingGuard

    attr_accessor :pending, :params_hash, :allowed, :redirected

    def session_limit_pending? = pending

    def params
      ActionController::Parameters.new(params_hash || {})
    end

    def flash
      @flash ||= {}
    end

    def redirect_to(*args, **kwargs)
      self.redirected = [args, kwargs]
    end

    def pending_session_limit_redirect_path = "/in/session"

    def pending_allowed_actions
      allowed.nil? ? super : allowed
    end

    def invoke(name, ...) = send(name, ...)
  end

  setup do
    @harness = Harness.new
    @harness.params_hash = { controller: "auth/app/sign/in/sessions", action: "show" }
  end

  test "a principal who is not parked at the session limit passes through untouched" do
    @harness.pending = false

    @harness.invoke(:redirect_pending_session_limit)

    assert_nil @harness.redirected
  end

  test "a parked principal is sent to the session management screen" do
    @harness.pending = true

    @harness.invoke(:redirect_pending_session_limit)

    assert_equal [["/in/session"], {}], @harness.redirected
    assert_equal I18n.t("session_limit.pending.message"), @harness.flash[:alert]
  end

  test "an action the controller allowlists is reachable while parked" do
    @harness.pending = true
    @harness.allowed = ["auth/app/sign/in/sessions#show"]

    @harness.invoke(:redirect_pending_session_limit)

    assert_nil @harness.redirected
  end

  test "the default allowlist is empty, so a controller that declares none parks every action" do
    @harness.pending = true
    @harness.allowed = nil

    assert_empty @harness.invoke(:pending_allowed_actions)

    @harness.invoke(:redirect_pending_session_limit)

    assert_equal [["/in/session"], {}], @harness.redirected
  end
end
