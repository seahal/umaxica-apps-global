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
end
