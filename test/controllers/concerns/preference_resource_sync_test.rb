# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceResourceSyncTest < ActiveSupport::TestCase
  class FakeConnection
    class << self
      attr_accessor :transactions, :writes

      def connected_to(role:)
        self.writes = writes.to_i + 1
        raise "wrong role" unless role == :writing

        yield
      end

      def transaction
        self.transactions = transactions.to_i + 1
        yield
      end
    end
  end

  class FakeResourcePreference
    attr_accessor :consented, :functional, :performant, :targetable, :consented_at, :saved, :updates

    def self.name = "ExamplePreference"

    def respond_to_missing?(*, **) = true

    def method_missing(name, *arguments)
      name.to_s.end_with?("=") ? instance_variable_set(:"@#{name.to_s.delete_suffix("=")}", arguments.first) : nil
    end

    def save! = self.saved = true

    def update!(attributes) = self.updates = attributes

    def attribute_names = %w(language region timezone theme density)
  end

  class Harness
    include PreferenceResourceSync

    attr_accessor :preferences, :resource, :preference_class_value

    def current_resource = resource

    def preference_current_resource = resource

    def preference_class = preference_class_value

    def preference_prefix = "App"

    def copy_preference_values!(source, target, prefix)
      @copied_values = [source, target, prefix]
    end

    def option_id_to_language(*) = nil

    def option_id_to_region(*) = nil

    def option_id_to_timezone(*) = nil

    def option_id_to_theme(*) = nil

    def option_id_to_preference_value(*) = nil

    def normalize_theme(value) = value

    attr_reader :copied_values

    def invoke(name, ...) = send(name, ...)
  end

  test "resource registry and association prefixes cover every surface" do
    harness = Harness.new

    assert_equal "Client", harness.invoke(:resource_preference_registry_prefix, ClientPreference.new)
    assert_equal "Operator", harness.invoke(:resource_preference_registry_prefix, OperatorPreference.new)
    assert_equal "Visitor", harness.invoke(:resource_preference_registry_prefix, VisitorPreference.new)
    assert_equal "client_preference", harness.invoke(:resource_preference_association_prefix, ClientPreference.new)
    assert_equal "operator_preference", harness.invoke(:resource_preference_association_prefix, OperatorPreference.new)
    assert_equal "visitor_preference", harness.invoke(:resource_preference_association_prefix, VisitorPreference.new)
  end

  test "direct preference snapshot contains only supported values" do
    preference = Struct.new(:language, :region, :timezone, :theme, :currency).new(
      "ja", "jp", "Asia/Tokyo", "dark", nil,
    )

    snapshot = Harness.new.invoke(:resolved_preference_snapshot, preference)

    assert_equal({ language: "ja", region: "jp", timezone: "Asia/Tokyo", theme: "dark" }, snapshot)
    assert_empty Harness.new.invoke(:resolved_preference_snapshot, nil)
  end

  test "cookie snapshot normalizes booleans and supplies defaults" do
    preference = Struct.new(:consented, :functional, :performant, :targetable).new(1, nil, true, false)
    harness = Harness.new

    assert_equal(
      { consented: true, functional: false, performant: true, targetable: false },
      harness.invoke(:resolved_preference_cookie, preference),
    )
    assert_equal(
      { consented: false, functional: false, performant: false, targetable: false },
      harness.invoke(:resolved_preference_cookie, nil),
    )
  end

  test "resource preference lookup covers app org and com" do
    harness = Harness.new
    app_resource = Struct.new(:user_preference).new(:app_preference)
    org_resource = Struct.new(:staff_preference).new(:org_preference)
    com_resource = Struct.new(:visitor_preference).new(:com_preference)

    harness.preference_class_value = AppPreference

    assert_equal :app_preference, harness.invoke(:preference_write_resource_preference!, app_resource)
    harness.preference_class_value = OrgPreference

    assert_equal :org_preference, harness.invoke(:preference_write_resource_preference!, org_resource)
    harness.preference_class_value = ComPreference

    assert_equal :com_preference, harness.invoke(:preference_write_resource_preference!, com_resource)
  end

  test "sync mirrors the direct and child preferences" do
    harness = Harness.new
    harness.resource = Object.new
    resource_preference = Object.new
    calls = []

    harness.stub(:preference_write_resource_preference!, resource_preference) do
      harness.stub(:sync_direct_resource_preference!, ->(value) { calls << [:direct, value] }) do
        harness.stub(:sync_resource_preference_children!, ->(value) { calls << [:children, value] }) do
          harness.invoke(:sync_to_resource_preference!)
        end
      end
    end

    assert_equal [[:direct, resource_preference], [:children, resource_preference]], calls
  end

  test "sync wraps unexpected failures and preserves resolution failures" do
    harness = Harness.new
    harness.resource = Object.new

    harness.stub(:preference_write_resource_preference!, ->(*) { raise ArgumentError, "bad preference" }) do
      assert_raises(PreferenceOperationError) { harness.invoke(:sync_to_resource_preference!) }
    end

    resolution_error = PreferenceBase::ResolutionError.new("unresolved")

    harness.stub(:preference_write_resource_preference!, ->(*) { raise resolution_error }) do
      assert_same resolution_error, assert_raises(PreferenceBase::ResolutionError) {
        harness.invoke(:sync_to_resource_preference!)
      }
    end
  end

  test "child sync uses the resource registry prefix" do
    harness = Harness.new
    harness.preferences = :source
    resource_preference = ClientPreference.new

    harness.invoke(:sync_resource_preference_children!, resource_preference)

    assert_equal [:source, resource_preference, "Client"], harness.copied_values
  end

  test "resource option values dispatch by type" do
    harness = Harness.new

    harness.stub(:option_id_to_language, "ja") do
      assert_equal "ja", harness.invoke(:resource_preference_value_for_option, "Client", :language, 1)
    end
    harness.stub(:option_id_to_region, "jp") do
      assert_equal "jp", harness.invoke(:resource_preference_value_for_option, "Client", :region, 1)
    end
    harness.stub(:option_id_to_timezone, "Asia/Tokyo") do
      assert_equal "Asia/Tokyo", harness.invoke(:resource_preference_value_for_option, "Client", :timezone, 1)
    end
    harness.stub(:option_id_to_theme, "dark") do
      harness.stub(:normalize_theme, "dr") do
        assert_equal "dr", harness.invoke(:resource_preference_value_for_option, "Client", :theme, 1)
      end
    end

    harness.stub(:option_id_to_preference_value, "compact") do
      assert_equal "compact", harness.invoke(:resource_preference_value_for_option, "Client", :density, 1)
    end
  end

  test "resource prefix methods fall back to the class name" do
    generic_class = Class.new
    generic_class.define_singleton_method(:name) { "ExamplePreference" }
    resource = generic_class.new
    harness = Harness.new

    assert_equal "Example", harness.invoke(:resource_preference_registry_prefix, resource)
    assert_equal "example_preference", harness.invoke(:resource_preference_association_prefix, resource)
  end

  test "cookie write filters unknown attributes" do
    resource = Struct.new(:updates) do
      def update!(attributes) = self.updates = attributes
    end.new
    connection =
      Class.new do
        def self.connected_to(role:)
          raise "wrong role" unless role == :writing

          yield
        end
      end
    harness = Harness.new

    harness.stub(:preference_connection_class, connection) do
      harness.invoke(
        :write_resource_preference_cookie!, resource,
        { consented: true, functional: true, ignored: "value" },
      )
    end

    assert_equal({ "consented" => true, "functional" => true }, resource.updates.to_h)
  end

  test "reset writes every default and clears consent" do
    resource = FakeResourcePreference.new
    child = Struct.new(:option_id, :updates) do
      def update!(attributes)
        self.option_id = attributes.fetch(:option_id)
        self.updates = attributes
      end
    end.new("old")
    option_class = Class.new { def self.ensure_defaults! = true }
    harness = Harness.new

    harness.stub(:preference_connection_class, FakeConnection) do
      harness.stub(:load_or_create_resource_preference_child!, child) do
        harness.stub(:resource_preference_value_for_option, "default") do
          PreferenceClassRegistry.stub(:option_class, option_class) do
            PreferenceClassRegistry.stub(:default_option_id, "default-id") do
              harness.invoke(:reset_resource_preference_defaults_for_write!, resource)
            end
          end
        end
      end
    end

    assert resource.saved
    assert_not resource.consented
    assert_not resource.functional
    assert_not resource.performant
    assert_not resource.targetable
    assert_nil resource.consented_at
    assert_equal "default-id", child.option_id
  end

  test "load or create child returns existing child and creates a missing child" do
    existing = Object.new
    resource = FakeResourcePreference.new
    resource.define_singleton_method(:example_preference_language) { existing }
    harness = Harness.new

    assert_same existing,
                harness.invoke(:load_or_create_resource_preference_child!, resource, "Example", :language)

    resource.define_singleton_method(:example_preference_language) { nil }
    resource.define_singleton_method(:create_example_preference_language!) { |attributes| attributes }
    PreferenceClassRegistry.stub(:default_option_id, "language-default") do
      created = harness.invoke(:load_or_create_resource_preference_child!, resource, "Example", :language)

      assert_equal({ option_id: "language-default" }, created)
    end
  end

  test "dual write transaction covers no owner same owner and separate owners" do
    harness = Harness.new
    token_owner = Class.new(FakeConnection)
    resource_owner = Class.new(FakeConnection)
    resource = Object.new

    harness.define_singleton_method(:preference_connection_owner) { nil }

    assert_equal :yielded, harness.invoke(:with_dual_write_transaction, resource) { :yielded }

    harness.define_singleton_method(:preference_connection_owner) { token_owner }

    harness.stub(:preference_connection_class, token_owner) do
      assert_equal :same, harness.invoke(:with_dual_write_transaction, resource) { :same }
    end

    harness.stub(:preference_connection_class, resource_owner) do
      assert_equal :separate, harness.invoke(:with_dual_write_transaction, resource) { :separate }
    end
    assert_equal 2, token_owner.transactions
    assert_equal 1, resource_owner.transactions
    assert_equal 1, resource_owner.writes
  end
end
