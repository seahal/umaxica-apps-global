# typed: false
# frozen_string_literal: true

require "test_helper"

class SignErrorResponsesIncludedDoTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include Sign::ErrorResponses
  end

  test "included do includes Common::Redirect module" do
    assert_includes Harness.included_modules, Common::Redirect,
                    "Harness should include Common::Redirect"
  end

  test "handle_application_error method exists" do
    harness = Harness.new

    assert_respond_to(harness, :handle_application_error)
  end

  test "handle_not_authorized method exists" do
    harness = Harness.new

    assert_respond_to(harness, :handle_not_authorized)
  end

  test "user_not_authorized alias exists" do
    harness = Harness.new

    assert_respond_to(harness, :user_not_authorized)
  end

  test "staff_not_authorized alias exists" do
    harness = Harness.new

    assert_respond_to(harness, :staff_not_authorized)
  end

  test "handle_csrf_failure method exists" do
    harness = Harness.new

    assert_respond_to(harness, :handle_csrf_failure)
  end

  test "safe_redirect_back_or_to method available via included Common::Redirect" do
    harness = Harness.new

    assert_includes harness.private_methods, :safe_redirect_back_or_to,
                    "safe_redirect_back_or_to should be a private method"
  end
end
