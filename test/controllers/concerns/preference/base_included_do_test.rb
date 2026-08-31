# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class PreferenceBaseIncludedDoTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include PreferenceBase
  end

  # The binding-method and DBSC-status tables also answer for the three token classes,
  # not just the three preference classes, and they refuse anything else by name rather
  # than returning nil into a caller far away.
  test "the binding method and dbsc status tables answer for preference and token classes" do
    {
      AppPreference => [AppPreferenceBindingMethod, AppPreferenceDbscStatus],
      ComPreference => [ComPreferenceBindingMethod, ComPreferenceDbscStatus],
      OrgPreference => [OrgPreferenceBindingMethod, OrgPreferenceDbscStatus],
      ClientToken => [ClientTokenBindingMethod, ClientTokenDbscStatus],
      OperatorToken => [OperatorTokenBindingMethod, OperatorTokenDbscStatus],
      VisitorToken => [VisitorTokenBindingMethod, VisitorTokenDbscStatus],
    }.each do |preference_class, (binding_method_class, dbsc_status_class)|
      harness = Harness.new
      harness.define_singleton_method(:preference_class) { preference_class }

      assert_equal binding_method_class, harness.send(:preference_binding_method_class), preference_class.name
      assert_equal dbsc_status_class, harness.send(:preference_dbsc_status_class), preference_class.name
    end
  end

  test "the binding method and dbsc status tables refuse an unknown class by name" do
    harness = Harness.new
    harness.define_singleton_method(:preference_class) { ClientEmail }

    %i(preference_binding_method_class preference_dbsc_status_class).each do |method_name|
      error = assert_raises(ArgumentError) { harness.send(method_name) }

      assert_match(/ClientEmail/, error.message)
    end
  end

  test "cookie_banner_endpoint_url method exists" do
    assert_includes PreferenceBase.private_instance_methods(false), :cookie_banner_endpoint_url
  end

  test "set_preferences_cookie method exists (private)" do
    assert_includes Harness.private_instance_methods, :set_preferences_cookie
    assert_includes PreferenceTransport.private_instance_methods(false), :set_preferences_cookie
  end

  test "ACCESS_TOKEN_TTL constant is defined" do
    assert_kind_of ActiveSupport::Duration, PreferenceBase::ACCESS_TOKEN_TTL
  end

  test "REFRESH_TOKEN_TTL constant is defined" do
    assert_kind_of ActiveSupport::Duration, PreferenceBase::REFRESH_TOKEN_TTL
  end

  test "including base does not register preference callbacks implicitly" do
    callbacks = Harness._process_action_callbacks.map(&:filter)

    assert_not_includes callbacks, :set_preferences_cookie
  end
end
