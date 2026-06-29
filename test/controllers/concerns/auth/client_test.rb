# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class TestAuthClientController < ApplicationController
  include AuthenticationClient
end

module Auth
  class AuthClientConcernTest < ActionDispatch::IntegrationTest
    setup do
      @controller = TestAuthClientController.new
    end

    test "Client concern includes AuthenticationBase" do
      assert_includes TestAuthClientController.ancestors, AuthenticationBase
    end

    test "constants are inherited from AuthenticationBase" do
      assert_equal AuthenticationBase::ACCESS_COOKIE_KEY, AuthenticationClient::ACCESS_COOKIE_KEY
      assert_equal AuthenticationBase::REFRESH_COOKIE_KEY, AuthenticationClient::REFRESH_COOKIE_KEY
      assert_equal AuthenticationBase::AUDIT_EVENTS, AuthenticationClient::AUDIT_EVENTS
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
