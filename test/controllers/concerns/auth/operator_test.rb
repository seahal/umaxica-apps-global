# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class TestAuthOperatorController < ApplicationController
  include AuthenticationOperator
end

module Auth
  class AuthOperatorConcernTest < ActionDispatch::IntegrationTest
    setup do
      @controller = TestAuthOperatorController.new
    end

    test "Operator concern includes AuthenticationBase" do
      assert_includes TestAuthOperatorController.ancestors, AuthenticationBase
    end

    test "constants are inherited from AuthenticationBase" do
      assert_equal AuthenticationBase::ACCESS_COOKIE_KEY, AuthenticationOperator::ACCESS_COOKIE_KEY
      assert_equal AuthenticationBase::REFRESH_COOKIE_KEY, AuthenticationOperator::REFRESH_COOKIE_KEY
      assert_equal AuthenticationBase::AUDIT_EVENTS, AuthenticationOperator::AUDIT_EVENTS
    end

    test "am_i_user? returns false" do
      assert_not @controller.am_i_user?
    end

    test "am_i_operator? returns true" do
      assert_predicate @controller, :am_i_operator?
    end

    test "am_i_owner? returns false" do
      assert_not @controller.am_i_owner?
    end

    test "active_operator? method exists" do
      assert_respond_to @controller, :active_operator?
    end
  end
end
