# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign::Com
  class ApplicationControllerTest < ActionDispatch::IntegrationTest
    test "includes expected concerns" do
      controller = ApplicationController.new

      assert_includes controller.class, ::Authentication::Customer
      assert_includes controller.class, ::Authorization::Customer
      assert_includes controller.class, ::Verification::Customer
      assert_includes controller.class, ActionPolicy::Controller
      assert_includes controller.class, ::CurrentSupport
    end

    test "has access_policy before verification" do
      callbacks = ApplicationController._process_action_callbacks
      before_filters = callbacks.select { |c| c.kind == :before }.map { |c| c.filter.to_s }

      assert_operator before_filters.index("enforce_access_policy!"), :<,
                      before_filters.index("enforce_verification_if_required")
    end
  end
end
