# typed: false
# frozen_string_literal: true

require "test_helper"

class CoverageClientAuthHarness < ApplicationController
  include AuthenticationClient

  attr_accessor :resource

  def current_resource = resource

  def authenticate! = (@authenticated = true)

  def record_audit(*) = (@audit_recorded = true)
end

class CoverageOperatorAuthHarness < ApplicationController
  include AuthenticationOperator

  attr_accessor :resource

  def current_resource = resource

  def authenticate! = (@authenticated = true)

  def record_audit(*) = (@audit_recorded = true)
end

class CoverageVisitorAuthHarness < ApplicationController
  include AuthenticationVisitor

  attr_accessor :resource

  def current_resource = resource

  def authenticate! = (@authenticated = true)

  def record_audit(*) = (@audit_recorded = true)
end

class CoverageThresholdAuthenticationHelpersTest < ActiveSupport::TestCase
  def active_double(active)
    Object.new.tap do |object|
      object.define_singleton_method(:active?) { active }
    end
  end

  test "client authentication concern exposes current and active client predicates" do
    harness = CoverageClientAuthHarness.new

    assert_nil harness.current_client
    assert_not_predicate harness, :logged_in_client?
    assert_not_predicate harness, :active_client?
    harness.resource = active_double(true)

    assert_same harness.resource, harness.current_client
    assert_predicate harness, :logged_in_client?
    assert_predicate harness, :active_client?
    assert_predicate harness, :am_i_client?
    assert_not_predicate harness, :am_i_staff?
    assert_not_predicate harness, :am_i_owner?
    assert_equal Client, harness.send(:resource_class)
    assert_equal ClientToken, harness.send(:token_class)
    assert_equal ClientChronicle, harness.send(:audit_class)
    assert_equal "client", harness.send(:resource_type)
    assert_equal :user_id, harness.send(:resource_foreign_key)
  end

  test "operator authentication concern exposes current and active operator predicates" do
    harness = CoverageOperatorAuthHarness.new

    assert_nil harness.current_operator
    assert_not_predicate harness, :logged_in_operator?
    assert_not_predicate harness, :active_operator?
    harness.resource = active_double(true)

    assert_same harness.resource, harness.current_operator
    assert_predicate harness, :logged_in_operator?
    assert_predicate harness, :active_operator?
    assert_not_predicate harness, :am_i_user?
    assert_predicate harness, :am_i_operator?
    assert_not_predicate harness, :am_i_owner?
    assert_equal Operator, harness.send(:resource_class)
    assert_equal OperatorToken, harness.send(:token_class)
    assert_equal OperatorChronicle, harness.send(:audit_class)
    assert_equal "operator", harness.send(:resource_type)
    assert_equal :staff_id, harness.send(:resource_foreign_key)
  end

  test "visitor authentication concern exposes current and active visitor predicates" do
    harness = CoverageVisitorAuthHarness.new

    assert_nil harness.current_visitor
    assert_not_predicate harness, :logged_in_visitor?
    assert_not_predicate harness, :active_visitor?
    harness.resource = active_double(true)

    assert_same harness.resource, harness.current_visitor
    assert_predicate harness, :logged_in_visitor?
    assert_predicate harness, :active_visitor?
    assert_not_predicate harness, :am_i_user?
    assert_not_predicate harness, :am_i_staff?
    assert_not_predicate harness, :am_i_owner?
    assert_equal Visitor, harness.send(:resource_class)
    assert_equal VisitorToken, harness.send(:token_class)
    assert_equal ClientChronicle, harness.send(:audit_class)
    assert_equal "visitor", harness.send(:resource_type)
    assert_equal :visitor_id, harness.send(:resource_foreign_key)
  end
end
