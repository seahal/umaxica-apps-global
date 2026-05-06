# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthenticationCustomerIncludedDoTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include Authentication::Customer
  end

  test "included do includes Authentication::Base module" do
    assert_includes Harness.included_modules, Authentication::Base
  end

  test "included do includes AuthorizationAudit module" do
    assert_includes Harness.included_modules, AuthorizationAudit
  end

  test "active_customer? method exists" do
    assert_includes Authentication::Customer.instance_methods(false), :active_customer?
  end

  test "audit_customer_login_failed method exists" do
    assert_includes Authentication::Customer.instance_methods(false), :audit_customer_login_failed
  end

  test "ACCESS_COOKIE_KEY constant is defined" do
    assert_equal Authentication::Base::ACCESS_COOKIE_KEY, Authentication::Customer::ACCESS_COOKIE_KEY
  end

  test "REFRESH_COOKIE_KEY constant is defined" do
    assert_equal Authentication::Base::REFRESH_COOKIE_KEY, Authentication::Customer::REFRESH_COOKIE_KEY
  end
end
