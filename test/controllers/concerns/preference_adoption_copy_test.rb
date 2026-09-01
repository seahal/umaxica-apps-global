# typed: false
# frozen_string_literal: true

require "test_helper"

# Copying preferences between the browser-scoped record and the principal-scoped
# one crosses two databases, so option ids cannot be copied directly -- they are
# resolved by name on the target side. A target that has no child row yet has
# one created from the registry default before the resolved value is written.
class PreferenceAdoptionCopyTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Child
    attr_accessor :option_id

    def initialize(option_id) = @option_id = option_id

    def update!(attributes)
      @option_id = attributes.fetch(:option_id)
    end
  end

  class Preference
    attr_reader :created

    def initialize(children)
      @children = children
      @created = []
    end

    def self.name = "PlainPreference"

    def update!(_attributes) = true

    def respond_to_missing?(name, include_private = false)
      @children.key?(name.to_s) || name.to_s.start_with?("create_") || super
    end

    def method_missing(name, *args, **kwargs)
      key = name.to_s
      return @children[key] if @children.key?(key)
      return nil if key.start_with?("plain_preference_")

      if key.start_with?("create_") && key.end_with?("!")
        association = key.delete_prefix("create_").delete_suffix("!")
        @created << association
        return @children[association] = Child.new(kwargs.fetch(:option_id))
      end

      super
    end
  end

  class Harness
    include PreferenceAdoption

    def invoke(name, ...) = send(name, ...)
  end

  setup do
    @harness = Harness.new
  end

  test "a target with no child row yet has one created from the registry default" do
    source = Preference.new("plain_preference_language" => Child.new(1))
    target = Preference.new({})
    option_class = Class.new do
      def self.ensure_defaults! = nil
    end

    PreferenceClassRegistry.stub(:option_class, option_class) do
      PreferenceClassRegistry.stub(:default_option_id, 99) do
        @harness.stub(:resolve_cross_db_option_id, 7) do
          @harness.invoke(:copy_preference_values!, source, target, :app)
        end
      end
    end

    assert_includes target.created, "plain_preference_language"
    assert_equal 7, target.public_send("plain_preference_language").option_id
  end
end
