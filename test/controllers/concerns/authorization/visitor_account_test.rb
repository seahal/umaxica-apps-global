# typed: false
# frozen_string_literal: true

require "test_helper"

class TestAuthorizationVisitorAccountController < ApplicationController
  include Authorization::VisitorAccount
end

module Authorization
  class VisitorAccountConcernTest < ActionDispatch::IntegrationTest
    setup do
      @controller = TestAuthorizationVisitorAccountController.new
    end

    test "Authorization::VisitorAccount is defined" do
      assert defined?(Authorization::VisitorAccount)
    end

    test "VisitorAccount concern includes Authorization::VisitorAccount" do
      assert_includes TestAuthorizationVisitorAccountController.ancestors, Authorization::VisitorAccount
    end

    test "VisitorAccount concern includes Authentication::Base" do
      assert_includes TestAuthorizationVisitorAccountController.ancestors, Authentication::Base
    end

    test "resource_class raises NotImplementedError" do
      assert_raises(NotImplementedError) do
        @controller.send(:resource_class)
      end
    end

    test "token_class raises NotImplementedError" do
      assert_raises(NotImplementedError) do
        @controller.send(:token_class)
      end
    end

    test "audit_class raises NotImplementedError" do
      assert_raises(NotImplementedError) do
        @controller.send(:audit_class)
      end
    end

    test "resource_type raises NotImplementedError" do
      assert_raises(NotImplementedError) do
        @controller.send(:resource_type)
      end
    end

    test "resource_foreign_key raises NotImplementedError" do
      assert_raises(NotImplementedError) do
        @controller.send(:resource_foreign_key)
      end
    end

    test "sign_in_url_with_return raises NotImplementedError" do
      assert_raises(NotImplementedError) do
        @controller.send(:sign_in_url_with_return, "/")
      end
    end

    test "current_resource method is available" do
      assert_respond_to @controller, :current_resource
    end

    test "logged_in? method is available" do
      assert_respond_to @controller, :logged_in?
    end

    test "log_in method is available" do
      assert_respond_to @controller, :log_in
    end

    test "log_out method is available" do
      assert_respond_to @controller, :log_out
    end

    test "authenticate! method is available" do
      assert_respond_to @controller, :authenticate!
    end

    test "am_i_user? raises NotImplementedError" do
      assert_raises(NotImplementedError) do
        @controller.am_i_user?
      end
    end

    test "am_i_operator? raises NotImplementedError" do
      assert_raises(NotImplementedError) do
        @controller.am_i_operator?
      end
    end

    test "am_i_owner? raises NotImplementedError" do
      assert_raises(NotImplementedError) do
        @controller.am_i_owner?
      end
    end
  end
end
