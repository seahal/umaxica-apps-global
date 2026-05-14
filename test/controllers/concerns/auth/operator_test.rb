# typed: false
# frozen_string_literal: true

require "test_helper"

class TestAuthOperatorController < ApplicationController
  include Authentication::Operator
end

module Auth
  class AuthOperatorConcernTest < ActionDispatch::IntegrationTest
    setup do
      @controller = TestAuthOperatorController.new
    end

    test "Operator concern includes Authentication::Base" do
      assert_includes TestAuthOperatorController.ancestors, Authentication::Base
    end

    test "constants are inherited from Authentication::Base" do
      assert_equal Authentication::Base::ACCESS_COOKIE_KEY, Authentication::Operator::ACCESS_COOKIE_KEY
      assert_equal Authentication::Base::REFRESH_COOKIE_KEY, Authentication::Operator::REFRESH_COOKIE_KEY
      assert_equal Authentication::Base::AUDIT_EVENTS, Authentication::Operator::AUDIT_EVENTS
    end

    test "resource_class returns Operator" do
      assert_equal ::Operator, @controller.send(:resource_class)
    end

    test "token_class returns OperatorToken" do
      assert_equal OperatorToken, @controller.send(:token_class)
    end

    test "audit_class returns OperatorChronicle" do
      assert_equal ::OperatorChronicle, @controller.send(:audit_class)
    end

    test "resource_type returns operator" do
      assert_equal "operator", @controller.send(:resource_type)
    end

    test "resource_foreign_key returns staff_id" do
      assert_equal :staff_id, @controller.send(:resource_foreign_key)
    end

    test "test_header_key returns X-TEST-CURRENT-STAFF" do
      assert_equal "X-TEST-CURRENT-STAFF", @controller.send(:test_header_key)
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
