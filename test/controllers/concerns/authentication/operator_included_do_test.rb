# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthenticationOperatorIncludedDoTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include AuthorizationAudit
    include Authentication::Operator
  end

  test "included do includes Authentication::Base module" do
    assert_includes Harness.included_modules, Authentication::Base
  end

  test "included do includes AuthorizationAudit module" do
    assert_includes Harness.included_modules, AuthorizationAudit
  end

  test "included do does not register refresh callback" do
    refresh_callbacks =
      Harness._process_action_callbacks.select { |callback|
        callback.kind == :before && callback.filter == :transparent_refresh_access_token
      }

    assert_empty refresh_callbacks
  end

  test "active_operator? method exists" do
    assert_includes Authentication::Operator.instance_methods(false), :active_operator?
  end

  test "audit_operator_login_failed method exists" do
    assert_includes Authentication::Operator.instance_methods(false), :audit_operator_login_failed
  end

  test "ACCESS_COOKIE_KEY constant is defined" do
    assert_equal Authentication::Base::ACCESS_COOKIE_KEY, Authentication::Operator::ACCESS_COOKIE_KEY
  end

  test "REFRESH_COOKIE_KEY constant is defined" do
    assert_equal Authentication::Base::REFRESH_COOKIE_KEY, Authentication::Operator::REFRESH_COOKIE_KEY
  end
end
