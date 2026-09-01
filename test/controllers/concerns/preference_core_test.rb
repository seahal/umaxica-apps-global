# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceCoreTest < ActiveSupport::TestCase
  AuditEvent = Struct.new(:unused)
  AuditEvent.const_set(:RESET_BY_USER_DECISION, "reset")

  class Harness
    def self.helper_method(*) = nil

    include PreferenceCore

    attr_accessor :preference_class_value, :resource

    def preference_class = preference_class_value

    def preference_prefix = "App"

    def preference_current_resource = resource

    def current_resource = resource

    def with_preference_connection(*) = yield

    def ensure_model_defaults!(*) = true

    def create_audit_log(*) = true

    def preference_audit_event_class = PreferenceCoreTest::AuditEvent

    def invoke(name, ...) = send(name, ...)
  end

  class ResetPreference
    attr_reader :child, :cookie
    attr_accessor :explicit_fields_cleared

    def self.name = "ExamplePreference"

    def initialize
      @child = Struct.new(:option_id, :updates) do
        def update!(attributes)
          self.option_id = attributes.fetch(:option_id)
          self.updates = attributes
        end
      end.new("old-id")
      @cookie = Struct.new(:updates) { def update!(attributes) = self.updates = attributes }.new
    end

    def method_missing(name, *)
      name.to_s.end_with?("_cookie") ? cookie : child
    end

    def respond_to_missing?(*, **) = true

    def clear_explicit_fields! = self.explicit_fields_cleared = true
  end

  # Resets the mirror association so the next read reloads it. The three surfaces name
  # their association differently and only the client one was ever exercised.
  class AssociationSpyResource
    ASSOCIATIONS = %i(user_preference staff_preference visitor_preference).freeze

    attr_reader :reset_associations

    def initialize
      @reset_associations = []
    end

    def respond_to?(name, include_private = false)
      ASSOCIATIONS.include?(name.to_sym) || super
    end

    def association(name)
      recorder = @reset_associations
      Object.new.tap { |proxy| proxy.define_singleton_method(:reset) { recorder << name } }
    end
  end

  # The three user-facing strings the preference actions answer with. Each resolves a
  # different key shape -- surface-scoped, acme-scoped, and a shared error -- so a
  # missing translation in any one of them would only show up here.
  test "the preference notice and alert helpers resolve their translation keys" do
    harness = Harness.new
    harness.define_singleton_method(:preference_translation_scope) { "acme.app.preference" }
    harness.define_singleton_method(:preference_surface_key) { "app" }
    harness.define_singleton_method(:t) { |key| "translated:#{key}" }

    assert_equal "translated:acme.app.preference.update_success", harness.invoke(:preference_update_notice)
    assert_equal "translated:acme.app.preference.resets.destroyed",
                 harness.invoke(:preference_reset_destroyed_notice)
    assert_equal I18n.t("errors.messages.preference_operation_failed"),
                 harness.invoke(:preference_operation_failed_alert)
  end

  test "resetting the mirror association picks the name that belongs to the surface" do
    {
      ClientPreference => :user_preference,
      OperatorPreference => :staff_preference,
      VisitorPreference => :visitor_preference,
    }.each do |preference_class, expected_association|
      resource = AssociationSpyResource.new
      harness = Harness.new
      harness.resource = resource

      harness.invoke(:reset_current_resource_preference_association, preference_class.new)

      assert_equal [expected_association], resource.reset_associations, preference_class.name
    end
  end

  test "reset helper restores child cookie and explicit defaults" do
    preference = ResetPreference.new
    option_class = Class.new
    harness = Harness.new

    PreferenceClassRegistry.stub(:option_class, option_class) do
      PreferenceClassRegistry.stub(:default_option_id, "default-id") do
        harness.invoke(:reset_app_org_preference_to_defaults!, preference)
      end
    end

    assert_equal "default-id", preference.child.option_id
    assert_equal(
      { consented: false, functional: false, performant: false, targetable: false, consented_at: nil },
      preference.cookie.updates,
    )
    assert preference.explicit_fields_cleared
  end

  test "full reset coordinates source mirror audit and token reload" do
    harness = Harness.new
    source = Object.new
    mirror = Object.new
    harness.instance_variable_set(:@preferences, source)
    calls = []

    harness.stub(:preference_write_resource_preference!, mirror) do
      harness.stub(:authorize_resource_preference_write!, ->(value) { calls << [:authorize, value] }) do
        harness.stub(:with_dual_write_transaction, ->(value, &block) { calls << [:transaction, value]; block.call }) do
          harness.stub(:reset_app_org_preference_to_defaults!, ->(value) { calls << [:source, value] }) do
            harness.stub(:reset_resource_preference_defaults_for_write!, ->(value) { calls << [:mirror, value] }) do
              harness.stub(:create_audit_log, ->(**) { calls << [:audit] }) do
                harness.stub(:reload_preferences_and_reissue_token!, ->(**) { calls << [:reload] }) do
                  harness.invoke(:reset_preference_to_defaults!)
                end
              end
            end
          end
        end
      end
    end

    assert_equal(
      [[:authorize, mirror], [:transaction, mirror], [:source, source], [:mirror, mirror], [:audit], [:reload]],
      calls,
    )
  end

  test "full reset translates expected write failures" do
    harness = Harness.new
    harness.instance_variable_set(:@preferences, Object.new)
    harness.define_singleton_method(:record_preference_write_error) { |*| @write_error_recorded = true }

    harness.stub(:preference_write_resource_preference!, -> { raise ArgumentError, "invalid" }) do
      assert_raises(PreferenceOperationError) { harness.invoke(:reset_preference_to_defaults!) }
    end
    assert harness.instance_variable_get(:@write_error_recorded)
  end

  test "existing resource lookup covers app org and com" do
    resource = Struct.new(:user_preference, :staff_preference, :visitor_preference).new(:app, :org, :com)
    harness = Harness.new
    harness.resource = resource

    harness.preference_class_value = AppPreference

    assert_equal :app, harness.invoke(:existing_resource_preference_for_reset)
    harness.preference_class_value = OrgPreference

    assert_equal :org, harness.invoke(:existing_resource_preference_for_reset)
    harness.preference_class_value = ComPreference

    assert_equal :com, harness.invoke(:existing_resource_preference_for_reset)
  end

  test "surface i18n and reset route helper names are deterministic" do
    harness = Harness.new
    harness.preference_class_value = AppPreference
    harness.define_singleton_method(:preference_route_authority) { "base" }

    assert_equal "acme.app.preferences", harness.invoke(:preference_translation_scope)
    assert_equal "base.app.preferences.title", harness.invoke(:preference_base_i18n_key, :preferences, :title)
    assert_equal "acme.app.preferences.title", harness.invoke(:preference_acme_i18n_key, :preferences, :title)
    assert_equal "base_app_preference_reset_url", harness.invoke(:preference_url_helper_name, :reset)
    assert_raises(ArgumentError) { harness.invoke(:preference_url_helper_name, :unknown) }
  end
end
