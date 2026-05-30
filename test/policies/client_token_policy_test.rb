# typed: false
# frozen_string_literal: true

require "test_helper"

class ClientTokenPolicyTest < ActiveSupport::TestCase
  fixtures_none!

  def setup
    @user = nil
    @record = nil
    @policy = ClientTokenPolicy.new(@record, user: @user)
  end

  def test_index
    assert_not @policy.index?
  end

  # index? gates the session listing to the owning actor type (Client).
  def test_index_allows_client
    assert_predicate ClientTokenPolicy.new(nil, user: Client.new), :index?
  end

  def test_index_denies_other_actor_types
    assert_not ClientTokenPolicy.new(nil, user: Operator.new).index?
    assert_not ClientTokenPolicy.new(nil, user: Visitor.new).index?
  end

  def test_show
    assert_not @policy.show?
  end

  def test_create
    assert_not @policy.create?
  end

  def test_new
    assert_not @policy.new?
  end

  def test_update
    assert_not @policy.update?
  end

  def test_edit
    assert_not @policy.edit?
  end

  def test_destroy
    assert_not @policy.destroy?
  end
end
