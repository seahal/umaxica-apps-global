# typed: false
# frozen_string_literal: true

require "test_helper"

class CspViolationReportTest < ActiveSupport::TestCase
  class Harness
    include CspViolationReport

    attr_reader :head_args

    def head(*args)
      @head_args = args
    end
  end

  class RateLimitedHarness < ApplicationController
    include CspViolationReport

    def self.rate_limit(**)
    end
  end

  test "ignore_malformed_csp_report returns no content" do
    harness = Harness.new

    harness.send(:ignore_malformed_csp_report)

    assert_equal [:no_content], harness.head_args
  end

  test "ignore_rate_limited_csp_report returns no content" do
    harness = Harness.new

    harness.send(:ignore_rate_limited_csp_report)

    assert_equal [:no_content], harness.head_args
  end

  test "protect_csp_violation_report_intake registers rescue and rate limit when available" do
    assert_nothing_raised do
      RateLimitedHarness.protect_csp_violation_report_intake
    end
  end
end
