# typed: false
# frozen_string_literal: true

require "test_helper"

class JumperTest < ActiveSupport::TestCase
  setup do
    Jumper.reset
  end

  teardown do
    Jumper.reset
  end

  test "default actor is unauthenticated" do
    assert_equal Unauthenticated.instance, Jumper.actor
  end

  test "default actor_type is :unauthenticated" do
    assert_equal :unauthenticated, Jumper.actor_type
  end

  test "user? returns true when actor_type is :user" do
    Jumper.actor_type = :user

    assert_predicate Jumper, :user?
    assert_not Jumper.staff?
    assert_not Jumper.customer?
  end

  test "staff? returns true when actor_type is :staff" do
    Jumper.actor_type = :staff

    assert_predicate Jumper, :staff?
    assert_not Jumper.user?
    assert_not Jumper.customer?
  end

  test "customer? returns true when actor_type is :customer" do
    Jumper.actor_type = :customer

    assert_predicate Jumper, :customer?
    assert_not Jumper.user?
    assert_not Jumper.staff?
  end

  test "unauthenticated? returns true when actor_type is :unauthenticated" do
    assert_predicate Jumper, :unauthenticated?
    Jumper.actor_type = :user

    assert_not Jumper.unauthenticated?
  end

  test "authenticated? returns true for user, staff, or customer" do
    assert_not Jumper.authenticated?

    Jumper.actor_type = :user

    assert_predicate Jumper, :authenticated?

    Jumper.actor_type = :staff

    assert_predicate Jumper, :authenticated?

    Jumper.actor_type = :customer

    assert_predicate Jumper, :authenticated?
  end

  test "user returns actor when actor_type is :user" do
    user = User.new(id: 123)
    Jumper.actor = user
    Jumper.actor_type = :user

    assert_equal user, Jumper.user
    assert_nil Jumper.staff
    assert_nil Jumper.customer
  end

  test "staff returns actor when actor_type is :staff" do
    staff = Staff.new(id: 456)
    Jumper.actor = staff
    Jumper.actor_type = :staff

    assert_equal staff, Jumper.staff
    assert_nil Jumper.user
    assert_nil Jumper.customer
  end

  test "customer returns actor when actor_type is :customer" do
    customer = Customer.new(id: 789)
    Jumper.actor = customer
    Jumper.actor_type = :customer

    assert_equal customer, Jumper.customer
    assert_nil Jumper.user
    assert_nil Jumper.staff
  end

  test "reset clears Jumper state" do
    Jumper.actor = User.new(id: 1)
    Jumper.actor_type = :user
    Jumper.domain = :app

    Jumper.reset

    assert_equal Unauthenticated.instance, Jumper.actor
    assert_equal :unauthenticated, Jumper.actor_type
    assert_nil Jumper.domain
  end

  test "reset does not clear Current" do
    Current.actor = User.new(id: 1)
    Current.actor_type = :user

    Jumper.actor = Staff.new(id: 2)
    Jumper.actor_type = :staff

    Jumper.reset

    # Current should remain unchanged
    assert_equal User.new(id: 1).class, Current.actor.class
    assert_equal :user, Current.actor_type
  end

  test "clear_all clears both Current and Jumper" do
    Current.actor = User.new(id: 1)
    Current.actor_type = :user
    Jumper.actor = Staff.new(id: 2)
    Jumper.actor_type = :staff

    ActiveSupport::CurrentAttributes.clear_all

    assert_equal Unauthenticated.instance, Current.actor
    assert_equal :unauthenticated, Current.actor_type
    assert_equal Unauthenticated.instance, Jumper.actor
    assert_equal :unauthenticated, Jumper.actor_type
  end

  test "domain can be set and retrieved" do
    Jumper.domain = :app

    assert_equal :app, Jumper.domain

    Jumper.domain = :com

    assert_equal :com, Jumper.domain

    Jumper.domain = :org

    assert_equal :org, Jumper.domain
  end
end
