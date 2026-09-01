# typed: false
# frozen_string_literal: true

require "test_helper"

# ActorSupport maps a persisted preference record onto the Actor::Preference value
# object, and picks the actor kind and the mirror association name per surface.
# These are pure translations with a per-surface branch each, so they are pinned
# directly rather than through a request.
class ActorSupportPreferenceMappingTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness
    include ActorSupport

    def invoke(name, ...) = send(name, ...)
  end

  class GateOption
    def initialize(name) = @name = name

    attr_reader :name
  end

  class GateStopper
    def initialize(option_name) = @option = GateOption.new(option_name)

    attr_reader :option
  end

  class ClientPreferenceRecord
    def self.name = "ClientPreference"

    def language = "en"

    def theme = "dr"

    def client_preference_adult_content_gate
      GateStopper.new("blocked")
    end
  end

  setup do
    Actor.clear if defined?(Actor)
    @harness = Harness.new
  end

  teardown { Actor.clear if defined?(Actor) }

  # Three fallbacks a surface reaches when it does not supply the optional seam, or
  # when the association it names is not there to reset.
  test "the optional actor-context seams fall back rather than raising" do
    assert_not @harness.invoke(:resolved_current_restricted_session?)
    # The resolver default is nil -- "no particular AAL demanded" -- so pin the
    # constant as well, or a later change to it would leave this reading as a
    # coincidental nil rather than as the fallback it is meant to assert.
    assert_nil StepUpResolver::DEFAULT_REQUIRED_AAL
    assert_nil @harness.invoke(:resolved_current_step_up_required_aal)

    without_association = Object.new

    assert_nil @harness.invoke(:reset_resource_preference_association, without_association, :user_preference)

    missing_association = Object.new
    missing_association.define_singleton_method(:association) do |_name|
      raise ActiveRecord::AssociationNotFoundError.new(Object.new, :user_preference)
    end

    assert_nil @harness.invoke(:reset_resource_preference_association, missing_association, :user_preference)
  end

  test "resolved_current_actor_type names the actor kind behind the record" do
    operator = Object.new
    operator.define_singleton_method(:operator?) { true }
    visitor = Object.new
    visitor.define_singleton_method(:operator?) { false }
    visitor.define_singleton_method(:visitor?) { true }

    assert_equal :operator, @harness.invoke(:resolved_current_actor_type, operator)
    assert_equal :visitor, @harness.invoke(:resolved_current_actor_type, visitor)
    assert_equal :client, @harness.invoke(:resolved_current_actor_type, Object.new)
    assert_equal :unauthenticated, @harness.invoke(:resolved_current_actor_type, nil)
  end

  test "resource_preference_association_name names the mirror each surface owns" do
    operator = Object.new
    operator.define_singleton_method(:operator?) { true }
    visitor = Object.new
    visitor.define_singleton_method(:operator?) { false }
    visitor.define_singleton_method(:visitor?) { true }

    assert_equal :staff_preference, @harness.invoke(:resource_preference_association_name, operator)
    assert_equal :visitor_preference, @harness.invoke(:resource_preference_association_name, visitor)
    assert_equal :user_preference, @harness.invoke(:resource_preference_association_name, Object.new)
    assert_nil @harness.invoke(:resource_preference_association_name, nil)
  end

  test "preference_record_value reads the record and falls back to the documented default" do
    record = ClientPreferenceRecord.new

    assert_equal "en", @harness.invoke(:preference_record_value, record, :language)
    assert_equal Actor::Preference::DEFAULTS.fetch(:currency),
                 @harness.invoke(:preference_record_value, record, :currency)
  end

  test "preference_record_value reads the adult content gate through its own association" do
    record = ClientPreferenceRecord.new

    assert_equal "blocked", @harness.invoke(:preference_record_value, record, :adult_content_gate)
    assert_equal "nothing", @harness.invoke(:preference_adult_content_gate_value, Object.new)
  end

  test "preference_from_record carries every field onto the value object" do
    preference = @harness.invoke(:preference_from_record, ClientPreferenceRecord.new, cookie: :cookie_value)

    assert_equal "en", preference.language
    assert_equal "dr", preference.theme
    assert_equal Actor::Preference::DEFAULTS.fetch(:region), preference.region
    assert_equal :cookie_value, preference.cookie
  end
end
