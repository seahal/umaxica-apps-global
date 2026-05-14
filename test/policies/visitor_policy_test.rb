# typed: false
# frozen_string_literal: true

require "test_helper"

class VisitorPolicyTest < ActiveSupport::TestCase
  class MockRecord
    attr_reader :id

    def initialize(id)
      @id = id
    end
  end

  def test_revoke_all_requires_same_visitor_actor
    visitor = build_actor(Visitor, 10)
    policy = VisitorPolicy.new(MockRecord.new(10), user: visitor)

    assert_predicate policy, :revoke_all?
  end

  def test_revoke_all_rejects_other_actor_types_and_ids
    visitor = build_actor(Visitor, 10)
    policy = VisitorPolicy.new(MockRecord.new(11), user: visitor)

    assert_not policy.revoke_all?

    staff = build_actor(Operator, 10)
    policy = VisitorPolicy.new(MockRecord.new(10), user: staff)

    assert_not policy.revoke_all?
  end

  def test_purge_sessions_allows_staff_only
    staff = build_actor(Operator, 20)
    policy = VisitorPolicy.new(MockRecord.new(20), user: staff)

    assert_predicate policy, :purge_sessions?

    visitor = build_actor(Visitor, 20)
    policy = VisitorPolicy.new(MockRecord.new(20), user: visitor)

    assert_not policy.purge_sessions?
  end

  private

  def build_actor(type_class, id)
    actor = Object.new
    actor.define_singleton_method(:id) { id }
    actor.define_singleton_method(:is_a?) do |klass|
      klass == type_class || super(klass)
    end
    actor
  end
end
