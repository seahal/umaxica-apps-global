# typed: false
# frozen_string_literal: true

require "test_helper"

# A principal whose account is in withdrawal may not reach ordinary endpoints.
# Browser requests are redirected into the withdrawal surface; anything that is
# not an HTML request is refused with a machine-readable status instead, because
# a redirect would be followed by an API client as if it had succeeded.
class WithdrawalGateAndLogoutSeamsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class GateHarness < ActionController::Base
    include AuthenticationWithdrawalGate

    attr_accessor :format_symbol, :rendered

    def logged_in? = true

    def current_resource = Object.new

    def withdrawal_restricted_resource?(_resource) = true

    def withdrawal_gate_allowlisted? = false

    def request
      Struct.new(:format).new(Mime[format_symbol || :json])
    end

    def render(*args, **kwargs)
      self.rendered = [args, kwargs]
    end

    def invoke(name, ...) = send(name, ...)
  end

  test "a json request from a withdrawing principal is refused with a machine-readable status" do
    harness = GateHarness.new
    harness.format_symbol = :json

    harness.invoke(:enforce_withdrawal_gate!)

    assert_equal [[], { json: { error: "WITHDRAWAL_REQUIRED" }, status: :forbidden }], harness.rendered
  end

  test "a non-html request from a withdrawing principal is refused the same way" do
    harness = GateHarness.new
    harness.format_symbol = :csv

    harness.invoke(:enforce_withdrawal_gate!)

    assert_equal [[], { json: { error: "WITHDRAWAL_REQUIRED" }, status: :forbidden }], harness.rendered
  end

  test "an rp logout ends the local session and returns to the site root without leaving the host" do
    harness = Class.new do
      include OidcRpLogout

      attr_reader :logged_out, :redirected

      def log_out
        @logged_out = true
      end

      def redirect_to(*args, **kwargs)
        @redirected = [args, kwargs]
      end
    end.new

    harness.create

    assert harness.logged_out
    assert_equal [["/"], { allow_other_host: false, status: :see_other }], harness.redirected
  end
end
