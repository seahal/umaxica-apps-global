# typed: false
# frozen_string_literal: true

require "test_helper"

# The session-limit cancellation endpoint is reachable only while a session-limit
# decision is actually pending. Everything else has to be turned away, and how it
# is turned away differs: a signed-in caller with no pending decision gets a flat
# refusal, an anonymous one is sent to sign in. Letting either through would let a
# caller cancel a session-limit hold that was never placed on them.
class SessionLimitCancellationAccessTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness
    include ::SignSessionLimitCancellationEndpoint

    attr_accessor :restricted, :expired, :pending_cycle, :gate_valid, :signed_in, :session, :redirects, :head_status

    def initialize
      @session = {}
      @redirects = []
    end

    def invoke(name, ...) = send(name, ...)

    def current_session_restricted? = restricted

    def restricted_session_expired? = expired

    def session_limit_gate_valid? = gate_valid

    def session_limit_pending_actor_session_key = :pending_actor_id

    def logged_in? = signed_in

    def head(status) = self.head_status = status

    def current_db_sign_in_flow_for_sequence
      pending_cycle && Struct.new(:sign_in_session_limit_pending?).new(true)
    end

    def session_limit_sign_in_path = "/sign/in?ri=jp"

    def redirect_to(path) = redirects << path
  end

  test "a restricted or expired session is allowed through to cancel" do
    restricted = Harness.new
    restricted.restricted = true

    assert_nil restricted.invoke(:require_session_limit_cancellation_access!)
    assert_empty restricted.redirects
    assert_nil restricted.head_status

    expired = Harness.new
    expired.expired = true

    assert_nil expired.invoke(:require_session_limit_cancellation_access!)
    assert_empty expired.redirects
  end

  test "a pending session-limit decision is allowed through to cancel" do
    harness = Harness.new
    harness.pending_cycle = true

    assert_nil harness.invoke(:require_session_limit_cancellation_access!)
    assert_empty harness.redirects
  end

  # A valid gate on its own is not enough: the pending actor has to be in the
  # session too, or the gate alone would authorise cancelling someone else's hold.
  test "a valid gate is only enough when it names the pending actor" do
    gate_only = Harness.new
    gate_only.gate_valid = true
    gate_only.signed_in = true

    gate_only.invoke(:require_session_limit_cancellation_access!)

    assert_equal :forbidden, gate_only.head_status

    with_actor = Harness.new
    with_actor.gate_valid = true
    with_actor.session[:pending_actor_id] = 42

    assert_nil with_actor.invoke(:require_session_limit_cancellation_access!)
    assert_nil with_actor.head_status
    assert_empty with_actor.redirects
  end

  test "an anonymous caller with nothing pending is sent to sign in rather than refused" do
    harness = Harness.new

    harness.invoke(:require_session_limit_cancellation_access!)

    assert_nil harness.head_status
    assert_equal ["/sign/in?ri=jp"], harness.redirects
  end

  test "the pending actor is taken from the session when no one is signed in" do
    harness = Harness.new
    harness.session[:pending_actor_id] = 42
    looked_up = []
    actor_class = Object.new
    actor_class.define_singleton_method(:find_by) { |id:| looked_up << id; :actor_from_session }
    harness.define_singleton_method(:session_limit_actor_class) { actor_class }
    harness.define_singleton_method(:current_resource) { nil }

    assert_equal :actor_from_session, harness.invoke(:resolve_session_limit_cancellation_actor)
    assert_equal [42], looked_up

    harness.define_singleton_method(:current_resource) { :signed_in_actor }

    assert_equal :signed_in_actor, harness.invoke(:resolve_session_limit_cancellation_actor)
  end
end
