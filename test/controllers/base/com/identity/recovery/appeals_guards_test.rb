# typed: false
# frozen_string_literal: true

require "test_helper"

# An appeal is only reachable from inside a live recovery ceremony. A request
# without one has the stale cookie cleared and is sent back to the ceremony
# entry point, rather than being shown a form whose submission would be refused.
class BaseComIdentityRecoveryAppealsGuardsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness < Base::Com::Identity::Recovery::AppealsController
    attr_accessor :params_hash, :cleared, :redirected

    def params
      ActionController::Parameters.new(params_hash || {})
    end

    def current_recovery_ceremony = nil

    def clear_recovery_ceremony_cookie!
      self.cleared = true
    end

    def safe_redirect_to(target, **)
      self.redirected = target
    end

    def invoke(name, ...) = send(name, ...)
  end

  test "a request with no live recovery ceremony clears the cookie and returns to the entry point" do
    harness = Harness.new
    harness.params_hash = { ri: "jp" }
    harness.request = ActionDispatch::TestRequest.create

    harness.invoke(:require_recovery_ceremony!)

    assert harness.cleared
    assert_includes harness.redirected, "/identity/recovery"
  end
end
