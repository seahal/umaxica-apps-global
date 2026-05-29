# typed: false
# frozen_string_literal: true

require "test_helper"

class OperatorPolicyTest < ActiveSupport::TestCase
  def test_index_returns_false_by_default
    policy = OperatorPolicy.new(Operator.new, user: nil)

    assert_not policy.index?
  end

  def test_show_returns_false_by_default
    policy = OperatorPolicy.new(Operator.new, user: nil)

    assert_not policy.show?
  end

  def test_create_returns_false_by_default
    policy = OperatorPolicy.new(Operator.new, user: nil)

    assert_not policy.create?
  end

  def test_update_returns_false_by_default
    policy = OperatorPolicy.new(Operator.new, user: nil)

    assert_not policy.update?
  end

  def test_destroy_returns_false_by_default
    policy = OperatorPolicy.new(Operator.new, user: nil)

    assert_not policy.destroy?
  end

  def test_revoke_all_allows_owner_operator
    owner = Operator.new(id: 1)
    policy = OperatorPolicy.new(owner, user: owner)

    assert_predicate policy, :revoke_all?
  end

  def test_revoke_all_denies_different_operator
    owner = Operator.new(id: 1)
    other = Operator.new(id: 2)
    policy = OperatorPolicy.new(owner, user: other)

    assert_not policy.revoke_all?
  end

  def test_revoke_all_denies_nil_user
    operator = Operator.new(id: 1)
    policy = OperatorPolicy.new(operator, user: nil)

    assert_not policy.revoke_all?
  end

  def test_revoke_all_denies_non_operator_user
    client = Client.new(id: 1)
    operator = Operator.new(id: client.id)
    policy = OperatorPolicy.new(operator, user: client)

    assert_not policy.revoke_all?
  end

  def test_purge_sessions_allows_operator
    operator = Operator.new(id: 1)
    policy = OperatorPolicy.new(Operator.new, user: operator)

    assert_predicate policy, :purge_sessions?
  end

  def test_purge_sessions_denies_nil_user
    policy = OperatorPolicy.new(Operator.new, user: nil)

    assert_not policy.purge_sessions?
  end

  def test_purge_sessions_denies_non_operator_user
    client = Client.new(id: 1)
    policy = OperatorPolicy.new(Operator.new, user: client)

    assert_not policy.purge_sessions?
  end
end
