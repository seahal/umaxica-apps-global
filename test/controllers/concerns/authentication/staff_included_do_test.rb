# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthenticationStaffIncludedDoTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include Authentication::Staff
  end

  test "included do includes Authentication::Base module" do
    assert_includes Harness.included_modules, Authentication::Base
  end

  test "included do includes AuthorizationAudit module" do
    assert_includes Harness.included_modules, AuthorizationAudit
  end

  test "active_staff? method exists" do
    assert_includes Authentication::Staff.instance_methods(false), :active_staff?
  end

  test "audit_staff_login_failed method exists" do
    assert_includes Authentication::Staff.instance_methods(false), :audit_staff_login_failed
  end

  test "ACCESS_COOKIE_KEY constant is defined" do
    assert_equal Authentication::Base::ACCESS_COOKIE_KEY, Authentication::Staff::ACCESS_COOKIE_KEY
  end

  test "REFRESH_COOKIE_KEY constant is defined" do
    assert_equal Authentication::Base::REFRESH_COOKIE_KEY, Authentication::Staff::REFRESH_COOKIE_KEY
  end
end
