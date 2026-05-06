# typed: false
# frozen_string_literal: true

require "test_helper"

class MinimumResponseBudgetIncludedDoTest < ActiveSupport::TestCase
  test "start_minimum_response_budget method exists (private)" do
    assert_includes MinimumResponseBudget.private_instance_methods(false), :start_minimum_response_budget
  end

  test "enforce_minimum_response_budget method exists (private)" do
    assert_includes MinimumResponseBudget.private_instance_methods(false), :enforce_minimum_response_budget
  end

  test "minimum_response_budget_enabled? method exists (private)" do
    assert_includes MinimumResponseBudget.private_instance_methods(false), :minimum_response_budget_enabled?
  end

  test "minimum_response_budget_ms method exists (private)" do
    assert_includes MinimumResponseBudget.private_instance_methods(false), :minimum_response_budget_ms
  end
end
