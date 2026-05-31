# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthenticationVisitorIncludedDoTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include AuthorizationAudit
    include Authentication::Visitor
  end

  test "included do includes Authentication::Base module" do
    assert_includes Harness.included_modules, Authentication::Base
  end

  test "included do includes AuthorizationAudit module" do
    assert_includes Harness.included_modules, AuthorizationAudit
  end

  test "active_visitor? method exists" do
    assert_includes Authentication::Visitor.instance_methods(false), :active_visitor?
  end

  test "audit_visitor_login_failed method exists" do
    assert_includes Authentication::Visitor.instance_methods(false), :audit_visitor_login_failed
  end

  test "ACCESS_COOKIE_KEY constant is defined" do
    assert_equal Authentication::Base::ACCESS_COOKIE_KEY, Authentication::Visitor::ACCESS_COOKIE_KEY
  end

  test "REFRESH_COOKIE_KEY constant is defined" do
    assert_equal Authentication::Base::REFRESH_COOKIE_KEY, Authentication::Visitor::REFRESH_COOKIE_KEY
  end
end
