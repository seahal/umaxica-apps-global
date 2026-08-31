# typed: false
# frozen_string_literal: true

require "test_helper"

# The step-up plumbing is written to fall back rather than raise: which token the
# session is keyed to, how a return target is decoded, and which of several
# parameter sources a scope arrives in all have a chain of alternatives. Each
# fallback is a place a step-up can silently attach to the wrong session or send
# the person somewhere unintended, and none of the tail arms had coverage.
class StepUpSessionStoreAndGatesTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class StoreHarness
    include ::SignVerificationStepUpSessionStore

    attr_accessor :session_token, :step_up_model

    def invoke(name, ...) = send(name, ...)

    def current_session_token = session_token

    def step_up_session_model = step_up_model || ClientStepUpSession
  end

  class ActorTokenStoreHarness < StoreHarness
    attr_accessor :actor_token_value

    def actor_token = actor_token_value
  end

  class GateHarness
    include ::SignVerificationCommonBase

    attr_accessor :params, :available_methods, :redirects, :scope_value, :recent_get, :recent_post, :consumed

    def initialize
      @params = ActionController::Parameters.new(ri: "jp")
      @redirects = []
      @available_methods = []
      @consumed = 0
    end

    def invoke(name, ...) = send(name, ...)

    def available_step_up_methods = available_methods

    def verification_unavailable_redirect_path = "/verification?ri=jp"

    def safe_redirect_to(*args, **kwargs) = redirects << [args, kwargs]

    def current_step_up_session = scope_value && Struct.new(:scope).new(scope_value)

    def verification_recent_for_get?(**) = recent_get

    def verification_recent_for_post?(**) = recent_post

    def consume_step_up_session! = self.consumed += 1
  end

  test "the step-up session follows the actor token when there is one and the session token otherwise" do
    with_actor = ActorTokenStoreHarness.new
    with_actor.actor_token_value = :actor_token
    with_actor.session_token = :session_token

    assert_equal :actor_token, with_actor.invoke(:current_step_up_token)

    with_actor.actor_token_value = nil

    assert_equal :session_token, with_actor.invoke(:current_step_up_token)
    assert_equal :session_token, StoreHarness.new.tap { |h| h.session_token = :session_token }
      .invoke(:current_step_up_token)
  end

  test "a return target with no decoder available is passed through as given" do
    harness = StoreHarness.new

    assert_equal "/settings/sessions", harness.invoke(:resolve_step_up_pt, "/settings/sessions")
    assert_nil harness.invoke(:resolve_step_up_pt, "")
  end

  test "the step-up session is keyed to the token column of its own surface" do
    harness = StoreHarness.new

    harness.step_up_model = ClientStepUpSession

    assert_equal :user_token_id, harness.invoke(:step_up_session_token_foreign_key)

    harness.step_up_model = VisitorStepUpSession

    assert_equal :visitor_token_id, harness.invoke(:step_up_session_token_foreign_key)

    harness.step_up_model = OperatorStepUpSession

    assert_equal :staff_token_id, harness.invoke(:step_up_session_token_foreign_key)

    harness.step_up_model = ClientToken

    assert_raises(NotImplementedError) { harness.invoke(:step_up_session_token_foreign_key) }
  end

  test "a step-up method the surface does not offer is refused with a redirect rather than attempted" do
    harness = GateHarness.new
    harness.available_methods = %i(email_otp)

    assert harness.invoke(:require_method_available!, :email_otp)
    assert_empty harness.redirects

    assert_not harness.invoke(:require_method_available!, :passkey)
    assert_equal 1, harness.redirects.size
    assert_equal I18n.t("auth.step_up.method_unavailable"), harness.redirects.first.last.fetch(:alert)
  end

  # A verification that is still recent is not asked for again; the step-up session
  # is consumed so the caller continues rather than looping back to the prompt.
  test "a recent verification consumes the step-up session instead of prompting again" do
    harness = GateHarness.new

    assert_not harness.invoke(:redirect_if_recent_verification_for_get!), "no scope means nothing to skip"
    assert_equal 0, harness.consumed

    harness.scope_value = "settings_email"
    harness.recent_get = false
    harness.recent_post = false

    assert_not harness.invoke(:redirect_if_recent_verification_for_get!)
    assert_not harness.invoke(:redirect_if_recent_verification_for_post!)
    assert_equal 0, harness.consumed

    harness.recent_get = true
    harness.recent_post = true

    assert harness.invoke(:redirect_if_recent_verification_for_get!)
    assert harness.invoke(:redirect_if_recent_verification_for_post!)
    assert_equal 2, harness.consumed
  end
end
