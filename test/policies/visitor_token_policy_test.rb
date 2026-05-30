# typed: false
# frozen_string_literal: true

require "test_helper"

# Object-level authorization for the com (visitor) session listing.
# index? allows only the owning actor type (Visitor); all other defaults stay deny-all.
class VisitorTokenPolicyTest < ActiveSupport::TestCase
  def setup
    @user = nil
    @record = nil
    @policy = VisitorTokenPolicy.new(@record, user: @user)
  end

  def test_index
    assert_not @policy.index?
  end

  def test_index_allows_visitor
    assert_predicate VisitorTokenPolicy.new(nil, user: Visitor.new), :index?
  end

  def test_index_denies_other_actor_types
    assert_not VisitorTokenPolicy.new(nil, user: Client.new).index?
    assert_not VisitorTokenPolicy.new(nil, user: Operator.new).index?
  end

  def test_show
    assert_not @policy.show?
  end

  def test_create
    assert_not @policy.create?
  end

  def test_update
    assert_not @policy.update?
  end

  def test_destroy
    assert_not @policy.destroy?
  end
end
