# typed: false
# frozen_string_literal: true

require "test_helper"

class TestAuthUserController < ApplicationController
  include Authentication::User
end

module Auth
  class AuthUserConcernTest < ActionDispatch::IntegrationTest
    setup do
      @controller = TestAuthUserController.new
    end

    test "User concern includes Authentication::Base" do
      assert_includes TestAuthUserController.ancestors, Authentication::Base
    end

    test "constants are inherited from Authentication::Base" do
      assert_equal Authentication::Base::ACCESS_COOKIE_KEY, Authentication::User::ACCESS_COOKIE_KEY
      assert_equal Authentication::Base::REFRESH_COOKIE_KEY, Authentication::User::REFRESH_COOKIE_KEY
      assert_equal Authentication::Base::AUDIT_EVENTS, Authentication::User::AUDIT_EVENTS
    end

    test "resource_class returns User" do
      assert_equal ::User, @controller.send(:resource_class)
    end

    test "token_class returns UserToken" do
      assert_equal UserToken, @controller.send(:token_class)
    end

    test "audit_class returns UserChronicle" do
      assert_equal ::UserChronicle, @controller.send(:audit_class)
    end

    test "resource_type returns user" do
      assert_equal "user", @controller.send(:resource_type)
    end

    test "resource_foreign_key returns user_id" do
      assert_equal :user_id, @controller.send(:resource_foreign_key)
    end

    test "test_header_key returns X-TEST-CURRENT-USER" do
      assert_equal "X-TEST-CURRENT-USER", @controller.send(:test_header_key)
    end

    test "am_i_user? returns true" do
      assert_predicate @controller, :am_i_user?
    end

    test "am_i_staff? returns false" do
      assert_not @controller.am_i_staff?
    end

    test "am_i_owner? returns false" do
      assert_not @controller.am_i_owner?
    end

    test "active_user? method exists" do
      assert_respond_to @controller, :active_user?
    end
  end
end
