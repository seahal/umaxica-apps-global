# typed: false
# frozen_string_literal: true

module MinimumResponseBudget
  extend ActiveSupport::Concern

  private

  def start_minimum_response_budget
    return unless minimum_response_budget_enforced?

    request.env["jit.min_response.started_at"] = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def enforce_minimum_response_budget
    return unless minimum_response_budget_enforced?

    started_at = request.env["jit.min_response.started_at"]
    return if started_at.nil?

    elapsed_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000.0
    remaining_ms = minimum_response_budget_ms - elapsed_ms
    return unless remaining_ms.positive?

    sleep([remaining_ms, minimum_response_budget_max_sleep_ms].min / 1000.0)
  end

  def minimum_response_budget_enabled?
    false
  end

  def minimum_response_budget_enforced?
    minimum_response_budget_enabled? && timing_protection_sleep_enabled?
  end

  def timing_protection_sleep_enabled?
    true
  end

  def minimum_response_budget_ms
    150.0
  end

  def minimum_response_budget_max_sleep_ms
    250.0
  end
end
