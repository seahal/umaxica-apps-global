# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class MinimumResponseBudgetTest < ActiveSupport::TestCase
  class Harness
    include MinimumResponseBudget

    attr_accessor :request, :slept

    def initialize
      @request = Struct.new(:env).new({})
      @slept = []
      @enabled = false
    end

    def minimum_response_budget_enabled?
      @enabled == true
    end

    def minimum_response_budget_enabled=(value)
      @enabled = value
    end

    def timing_protection_sleep_enabled?
      @timing_enabled != false
    end

    def timing_protection_sleep_enabled=(value)
      @timing_enabled = value
    end

    def sleep(seconds)
      @slept << seconds
    end
  end

  test "start and enforce do nothing when disabled" do
    harness = Harness.new

    harness.send(:start_minimum_response_budget)
    harness.send(:enforce_minimum_response_budget)

    assert_empty harness.request.env
    assert_empty harness.slept
  end

  test "start stores a monotonic timestamp and enforce sleeps for the remaining budget" do
    harness = Harness.new
    harness.minimum_response_budget_enabled = true

    Process.stub(:clock_gettime, 100.0) do
      harness.send(:start_minimum_response_budget)
    end

    Process.stub(:clock_gettime, 100.1) do
      harness.send(:enforce_minimum_response_budget)
    end

    assert_in_delta 0.05, harness.slept.first, 0.001
    assert_includes harness.request.env, "jit.min_response.started_at"
  end

  test "enforce returns early when the elapsed time already exceeds the budget" do
    harness = Harness.new
    harness.minimum_response_budget_enabled = true

    Process.stub(:clock_gettime, 100.0) do
      harness.send(:start_minimum_response_budget)
    end

    Process.stub(:clock_gettime, 101.0) do
      harness.send(:enforce_minimum_response_budget)
    end

    assert_empty harness.slept
  end

  test "minimum_response_budget_ms and max sleep are stable defaults" do
    harness = Harness.new

    assert_in_delta(150.0, harness.send(:minimum_response_budget_ms))
    assert_in_delta(250.0, harness.send(:minimum_response_budget_max_sleep_ms))
  end

  test "default budget is enabled and timing protection sleep is enabled" do
    plain = Class.new { include MinimumResponseBudget }.new

    assert plain.send(:minimum_response_budget_enabled?)
    assert plain.send(:timing_protection_sleep_enabled?)
  end

  test "org entra authorization uses the secure default budget" do
    controller = Auth::Org::Sign::In::Entra::AuthorizationsController.new
    controller.define_singleton_method(:action_name) { "create" }

    assert controller.send(:minimum_response_budget_enabled?)
  end

  test "sign-in secret credential controllers enable the budget only for create" do
    [
      Auth::App::Sign::In::SecretCredentialsController,
      Auth::Com::Sign::In::SecretCredentialsController,
      Auth::Org::Sign::In::SecretCredentialsController,
    ].each do |controller_class|
      controller = controller_class.new
      controller.define_singleton_method(:action_name) { "create" }

      assert controller.send(:minimum_response_budget_enabled?)

      controller.define_singleton_method(:action_name) { "new" }

      assert_not controller.send(:minimum_response_budget_enabled?), controller_class.name
    end
  end
end
