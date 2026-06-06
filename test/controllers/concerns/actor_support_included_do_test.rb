# typed: false
# frozen_string_literal: true

require "test_helper"

class ActorSupportIncludedDoTest < ActiveSupport::TestCase
  test "include does not register lifecycle callbacks implicitly" do
    harness =
      Class.new(ApplicationController) do
        include ActorSupport
      end

    callbacks = harness._process_action_callbacks.map(&:filter)

    assert_not_includes callbacks, :_reset_current_state
    assert_not_includes callbacks, :set_current_context
    assert_not_includes callbacks, :set_current_actor
  end

  test "current lifecycle methods exist in module" do
    assert_includes ActorSupport.private_instance_methods(false), :set_current_context
    assert_includes ActorSupport.private_instance_methods(false), :set_current_actor
    assert_includes ActorSupport.private_instance_methods(false), :set_current
    assert_includes ActorSupport.private_instance_methods(false), :_reset_current_state
    assert_includes ActorSupport.private_instance_methods(false), :with_actor_lifecycle
  end

  test "resolved_current_tld method exists in module" do
    assert_includes ActorSupport.private_instance_methods(false), :resolved_current_tld
  end

  test "set_current_context populates unauthenticated request context" do
    Actor.install_context!(
      authn: Actor::Authentication.new(
        login_public_id: "stale-session",
        access_claims: { "sid" => "stale-session" },
      ),
    )
    Actor.install_context!(preferences: Actor::Preference.new(language: "en"))
    Actor.trace_id = "trace"
    Actor.span_id = "span"

    controller = actor_support_controller
    controller.send(:set_current_context)

    assert_equal Unauthenticated.instance, Actor.actor
    assert_equal :unauthenticated, Actor.actor_type
    assert_nil Actor.tld
    assert_equal Actor::Authentication::NULL, Actor.authn
    assert_equal Actor::Configuration::NULL, Actor.configuration
    assert_equal Actor::Preference::NULL, Actor.preferences
    assert_nil Actor.trace_id
    assert_nil Actor.span_id
  ensure
    Actor.reset
  end

  test "set_current populates Actor context" do
    controller = actor_support_controller
    controller.send(:set_current)

    assert_equal Unauthenticated.instance, Actor.actor
    assert_equal :unauthenticated, Actor.actor_type
    assert_nil Actor.tld
    assert_equal Actor::Authentication::NULL, Actor.authn
    assert_equal Actor::Configuration::NULL, Actor.configuration
    assert_equal Actor::Preference::NULL, Actor.preferences
  ensure
    Actor.reset
  end

  test "_reset_current_state resets Actor context" do
    Actor.actor = Client.new(id: 1)
    Actor.actor_type = :client
    Actor.tld = :app
    Actor.install_context!(
      authn: Actor::Authentication.new(
        login_public_id: "session-1",
        access_claims: { "sid" => "session-1" },
      ),
    )
    Actor.configuration = Actor::Configuration.new(feature: true)
    Actor.install_context!(preferences: Actor::Preference.new(language: "en"))

    actor_support_controller.send(:_reset_current_state)

    assert_equal Unauthenticated.instance, Actor.actor
    assert_equal :unauthenticated, Actor.actor_type
    assert_nil Actor.tld
    assert_equal Actor::Authentication::NULL, Actor.authn
    assert_equal Actor::Configuration::NULL, Actor.configuration
    assert_equal Actor::Preference::NULL, Actor.preferences
  end

  test "with_actor_lifecycle clears Actor context after block" do
    controller = actor_support_controller

    controller.send(:with_actor_lifecycle) do
      Actor.actor_type = :client
      Actor.install_context!(authn: Actor::Authentication.new(login_public_id: "session-1"))
    end

    assert_equal :unauthenticated, Actor.actor_type
    assert_equal Actor::Authentication::NULL, Actor.authn
  end

  test "with_actor_lifecycle clears Actor context after exception" do
    controller = actor_support_controller

    assert_raises RuntimeError do
      controller.send(:with_actor_lifecycle) do
        Actor.actor_type = :client
        raise RuntimeError, "boom"
      end
    end

    assert_equal :unauthenticated, Actor.actor_type
  end

  test "resolved active sign sequence id ignores terminal and expired sequences" do
    controller = actor_support_controller
    actor = Client.new(id: 1)
    Actor.tld = :app
    carrier = SignInSequenceCarrier.new(controller.session, surface: :app)
    sequence = carrier.start!(
      surface: :app,
      actor: actor,
      method: :email_otp,
      state: "CHECKPOINT_PENDING",
      participant: :checkpoint,
      pt: nil,
    )

    assert_equal sequence.id, controller.send(:resolved_active_sign_sequence_id)

    carrier.fail!

    assert_nil controller.send(:resolved_active_sign_sequence_id)

    carrier.start!(
      surface: :app,
      actor: actor,
      method: :email_otp,
      state: "CHECKPOINT_PENDING",
      participant: :checkpoint,
      pt: nil,
    )
    controller.session[:app_sign_in_sequence]["expires_at"] = 1.minute.ago.iso8601

    assert_nil controller.send(:resolved_active_sign_sequence_id)
  ensure
    Actor.reset
  end

  private

  def actor_support_controller
    Class.new(ApplicationController) do
      include ActorSupport

      define_method(:request) do
        nil
      end

      define_method(:current_resource) do
        nil
      end

      define_method(:session) do
        @session ||= {}
      end
    end.new
  end
end
