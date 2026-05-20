# typed: false
# frozen_string_literal: true

require "test_helper"

class TestAuthClientController < ApplicationController
  include Authentication::Client
end

module Auth
  class AuthClientConcernTest < ActionDispatch::IntegrationTest
    setup do
      @controller = TestAuthClientController.new
    end

    test "Client concern includes Authentication::Base" do
      assert_includes TestAuthClientController.ancestors, Authentication::Base
    end

    test "constants are inherited from Authentication::Base" do
      assert_equal Authentication::Base::ACCESS_COOKIE_KEY, Authentication::Client::ACCESS_COOKIE_KEY
      assert_equal Authentication::Base::REFRESH_COOKIE_KEY, Authentication::Client::REFRESH_COOKIE_KEY
      assert_equal Authentication::Base::AUDIT_EVENTS, Authentication::Client::AUDIT_EVENTS
    end

    test "resource_class returns Client" do
      assert_equal ::Client, @controller.send(:resource_class)
    end

    test "token_class returns ClientToken" do
      assert_equal ClientToken, @controller.send(:token_class)
    end

    test "audit_class returns ClientChronicle" do
      assert_equal ::ClientChronicle, @controller.send(:audit_class)
    end

    test "resource_type returns client" do
      assert_equal "client", @controller.send(:resource_type)
    end

    test "resource_foreign_key returns user_id" do
      assert_equal :user_id, @controller.send(:resource_foreign_key)
    end

    test "am_i_client? returns true" do
      assert_predicate @controller, :am_i_client?
    end

    test "am_i_staff? returns false" do
      assert_not @controller.am_i_staff?
    end

    test "am_i_owner? returns false" do
      assert_not @controller.am_i_owner?
    end

    test "active_client? method exists" do
      assert_respond_to @controller, :active_client?
    end
  end
end
