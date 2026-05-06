# typed: false
# frozen_string_literal: true

require "test_helper"

class ComContactPolicyTest < ActiveSupport::TestCase
  fixtures :users, :user_statuses

  fixtures :staffs, :staff_statuses, :users, :user_statuses

  class MockContact
    def initialize
    end
  end

  def setup
    @user = nil
    @record = MockContact.new
    @policy = ComContactPolicy.new(@record, user: @user)
  end

  def test_policy_initializes_with_user_and_record
    policy = ComContactPolicy.new(@record, user: @user)

    assert_nil policy.user
    assert_equal @record, policy.record
  end

  def test_index
    # Staff can view
    staff = staffs(:one)
    policy = ComContactPolicy.new(@record, user: staff)
    policy.define_singleton_method(:can_view?) { true }

    assert_predicate policy, :index?

    # Staff without view permission cannot view
    policy = ComContactPolicy.new(@record, user: staff)
    policy.define_singleton_method(:can_view?) { false }

    assert_not policy.index?

    # User cannot view
    user = users(:one)
    policy = ComContactPolicy.new(@record, user: user)
    # create? is false by default for user in logic if not stubbed? No, index
    # logic: actor.is_a?(Staff) && can_view?
    # User is not Staff, so should be false regardless of can_view?
    policy.define_singleton_method(:can_view?) { true }

    assert_not policy.index?

    # Nil actor cannot view
    policy = ComContactPolicy.new(@record, user: nil)

    assert_not policy.index?
  end

  def test_show
    # Staff can view
    staff = staffs(:one)
    policy = ComContactPolicy.new(@record, user: staff)
    policy.define_singleton_method(:can_view?) { true }

    assert_predicate policy, :show?

    # Staff without view permission cannot view (unless owner, but staff isn't owner here)
    policy = ComContactPolicy.new(@record, user: staff)
    policy.define_singleton_method(:can_view?) { false }

    assert_not policy.show?

    # Owner user can view
    user = users(:one)
    record = OpenStruct.new(user_id: user.id)
    policy = ComContactPolicy.new(record, user: user)

    assert_predicate policy, :show?

    # Other user cannot view
    other_user = users(:two)
    policy = ComContactPolicy.new(record, user: other_user)
    # User is not Staff, so can_view? is not checked or doesn't matter for first clause.
    # Logic: (actor.is_a?(Staff) && can_view?) || owner?
    # User is not staff. Owner? is false.
    assert_not policy.show?
  end

  def test_create
    # Nil actor can create
    policy = ComContactPolicy.new(@record, user: nil)

    assert_predicate policy, :create?

    # User can create
    user = users(:one)
    policy = ComContactPolicy.new(@record, user: user)

    assert_predicate policy, :create?

    # Staff cannot create
    staff = staffs(:one)
    policy = ComContactPolicy.new(@record, user: staff)

    assert_not policy.create?
  end

  def test_update
    # Operator staff can update
    staff = staffs(:one) # assuming fixture one is admin/manager-like? We might need to mock operator_or_manager?
    # Helper to stub permissions helper since we don't know exact implementation
    # of operator_or_manager? in ApplicationPolicy or its mixins from just this file.
    # Looking at ApplicationPolicy would be good but usually we can stub.

    # Let's check ApplicationPolicy if we can or just stub methods on policy instance.
    # But usually we test policy logic.

    # Assuming standard roles, let's just stub the method on policy instance

    policy = ComContactPolicy.new(@record, user: staff)
    policy.define_singleton_method(:operator_or_manager?) { true }

    assert_predicate policy, :update?

    policy = ComContactPolicy.new(@record, user: staff)
    policy.define_singleton_method(:operator_or_manager?) { false }

    assert_not policy.update?

    # User cannot update
    user = users(:one)
    policy = ComContactPolicy.new(@record, user: user)

    assert_not policy.update?
  end

  def test_destroy
    staff = staffs(:one)

    # Operator can destroy
    policy = ComContactPolicy.new(@record, user: staff)
    policy.define_singleton_method(:operator?) { true }

    assert_predicate policy, :destroy?

    # Non-admin cannot destroy
    policy = ComContactPolicy.new(@record, user: staff)
    policy.define_singleton_method(:operator?) { false }

    assert_not policy.destroy?
  end

  def test_show_allows_owner_even_if_not_staff
    user = users(:one)
    record = OpenStruct.new(user_id: user.id)
    policy = ComContactPolicy.new(record, user: user)

    assert_predicate policy, :show?
  end

  def test_show_denies_owner_when_staff_needs_view
    staff = staffs(:one)
    record = OpenStruct.new(user_id: 999)
    policy = ComContactPolicy.new(record, user: staff)
    policy.define_singleton_method(:can_view?) { false }

    assert_not policy.show?
  end
end
