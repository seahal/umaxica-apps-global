# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceGlobalIncludedDoTest < ActiveSupport::TestCase
  test "effective_context method exists" do
    assert_includes PreferenceGlobal.instance_methods(false), :effective_context
  end

  test "required_ri method exists" do
    assert_includes PreferenceGlobal.instance_methods(false), :required_ri
  end

  test "resolve_param_context method exists" do
    assert_includes PreferenceGlobal.instance_methods(false), :resolve_param_context
  end

  test "default_context method exists" do
    assert_includes PreferenceGlobal.instance_methods(false), :default_context
  end

  test "including global does not register localization callback implicitly" do
    controller =
      Class.new(ApplicationController) do
        include PreferenceGlobal
      end

    callbacks = controller._process_action_callbacks.map(&:filter)

    assert_not_includes callbacks, :apply_localization_preferences
  end
end
