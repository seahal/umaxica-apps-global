# typed: false
# frozen_string_literal: true

require "test_helper"

class CurrentSupportIncludedDoTest < ActiveSupport::TestCase
  test "included do registers after_action callback" do
    harness =
      Class.new(ApplicationController) do
        include CurrentSupport
      end

    after_filters = harness._process_action_callbacks.select { |c| c.kind == :after }.map(&:filter)

    assert_includes after_filters, :_reset_current_state
  end

  test "set_current method exists in module" do
    assert_includes CurrentSupport.private_instance_methods(false), :set_current
  end

  test "_reset_current_state method exists in module" do
    assert_includes CurrentSupport.private_instance_methods(false), :_reset_current_state
  end

  test "resolved_current_domain method exists in module" do
    assert_includes CurrentSupport.private_instance_methods(false), :resolved_current_domain
  end

  test "set_current populates Actor context" do
    controller = current_support_controller
    controller.send(:set_current)

    assert_equal Unauthenticated.instance, Actor.actor
    assert_equal :unauthenticated, Actor.actor_type
    assert_nil Actor.surface
    assert_equal Actor::Preference::NULL, Actor.preference
  ensure
    Actor.reset
  end

  test "_reset_current_state resets Actor context" do
    Actor.actor = User.new(id: 1)
    Actor.actor_type = :user
    Actor.surface = :app
    Actor.domain = :app
    Actor.session = "session-1"
    Actor.token = { "sid" => "session-1" }
    Actor.preference = Actor::Preference.new(language: "en")

    current_support_controller.send(:_reset_current_state)

    assert_equal Unauthenticated.instance, Actor.actor
    assert_equal :unauthenticated, Actor.actor_type
    assert_nil Actor.surface
    assert_nil Actor.domain
    assert_nil Actor.session
    assert_nil Actor.token
    assert_equal Actor::Preference::NULL, Actor.preference
  end

  private

  def current_support_controller
    Class.new(ApplicationController) do
      include CurrentSupport

      define_method(:request) do
        nil
      end

      define_method(:current_resource) do
        nil
      end
    end.new
  end
end
