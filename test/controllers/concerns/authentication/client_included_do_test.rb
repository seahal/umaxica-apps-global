# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthenticationClientIncludedDoTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include Authentication::Client
  end

  test "included do includes Authentication::Base module" do
    assert_includes Harness.included_modules, Authentication::Base
  end

  test "included do includes AuthorizationAudit module" do
    assert_includes Harness.included_modules, AuthorizationAudit
  end

  test "active_client? method exists" do
    assert_includes Authentication::Client.instance_methods(false), :active_client?
  end

  test "audit_client_login_failed method exists" do
    assert_includes Authentication::Client.instance_methods(false), :audit_client_login_failed
  end

  test "ACCESS_COOKIE_KEY constant is defined" do
    assert_equal Authentication::Base::ACCESS_COOKIE_KEY, Authentication::Client::ACCESS_COOKIE_KEY
  end

  test "REFRESH_COOKIE_KEY constant is defined" do
    assert_equal Authentication::Base::REFRESH_COOKIE_KEY, Authentication::Client::REFRESH_COOKIE_KEY
  end
end
