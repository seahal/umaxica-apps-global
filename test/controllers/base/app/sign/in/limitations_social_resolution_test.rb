# typed: false
# frozen_string_literal: true

require "test_helper"

# A social sign-in parked at the session limit is resumed from a signed
# resolution payload. The payload must name the same actor and, when it names
# one, the same session as the restricted token being promoted -- otherwise a
# resolution issued for one session would promote another.
class Base::App::Sign::In::LimitationsSocialResolutionTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness < Base::App::Sign::In::LimitationsController
    attr_accessor :session_double, :invalid_rendered

    def current_session = session_double

    def render_invalid_resolution
      self.invalid_rendered = true
    end

    attr_reader :redirected

    def redirect_to(*args, **kwargs)
      @redirected = [args, kwargs]
    end

    def invoke(name, ...) = send(name, ...)
  end

  setup do
    @harness = Harness.new
    @harness.request = ActionDispatch::TestRequest.create
    @actor = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @harness.instance_variable_set(:@actor, @actor)
  end

  def restricted_session(user_id:, public_id: "session-1")
    session = Struct.new(:user_id, :public_id, :promoted).new(user_id, public_id, false)
    session.define_singleton_method(:restricted?) { true }
    session.define_singleton_method(:promote_to_active!) { self.promoted = true }
    session
  end

  test "a resolution for a different actor is refused rather than promoting the session" do
    @harness.session_double = restricted_session(user_id: @actor.id + 1)
    @harness.instance_variable_set(:@social_resolution_payload, {})

    @harness.invoke(:promote_social_resolution_session)

    assert @harness.invalid_rendered
    assert_not @harness.session_double.promoted
  end

  test "a resolution naming a different session is refused rather than promoting this one" do
    @harness.session_double = restricted_session(user_id: @actor.id, public_id: "session-1")
    @harness.instance_variable_set(:@social_resolution_payload, { "session_ref" => "session-2" })

    @harness.invoke(:promote_social_resolution_session)

    assert @harness.invalid_rendered
    assert_not @harness.session_double.promoted
  end

  test "a resolution naming this actor and this session promotes it" do
    @harness.session_double = restricted_session(user_id: @actor.id, public_id: "session-1")
    @harness.instance_variable_set(:@social_resolution_payload, { "session_ref" => "session-1" })

    @harness.invoke(:promote_social_resolution_session)

    assert_not @harness.invalid_rendered
    assert @harness.session_double.promoted
  end

  # The resolution token arrives from the browser, so every way it can be
  # unusable -- a bad signature, a missing claim, an unparsable expiry -- has to
  # end with no resolution rather than an exception inside the before_action.
  test "a resolution token that does not verify resolves to no payload" do
    @harness.instance_variable_set(:@social_resolution_token, "not-a-signed-token")

    @harness.invoke(:load_social_resolution)

    assert_nil @harness.instance_variable_get(:@social_resolution_payload)
    assert_not @harness.invoke(:social_resolution?)
  end

  test "a resolution token missing its expiry claim resolves to no payload" do
    token = Rails.application.message_verifier(:social_session_limit_limitation).generate({ "actor_ref" => "x" })
    @harness.instance_variable_set(:@social_resolution_token, token)

    @harness.invoke(:load_social_resolution)

    assert_nil @harness.instance_variable_get(:@social_resolution_payload)
  end
end
