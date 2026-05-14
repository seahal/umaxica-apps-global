# typed: false
# frozen_string_literal: true

require "test_helper"

class OperatorPolicyTest < ActiveSupport::TestCase
  class MockOperator
    def initialize
    end
  end

  def setup
    @user = nil
    @record = MockOperator.new
    @policy = OperatorPolicy.new(@record, user: @user)
  end

  def test_policy_initializes_with_user_and_record
    policy = OperatorPolicy.new(@record, user: @user)

    assert_nil policy.user
    assert_equal @record, policy.record
  end

  def test_index_returns_false_by_default
    assert_not @policy.send(:index?)
  end

  def test_show_returns_false_by_default
    assert_not @policy.send(:show?)
  end

  def test_create_returns_false_by_default
    assert_not @policy.send(:create?)
  end

  def test_new_delegates_to_create
    assert_equal @policy.send(:create?), @policy.send(:new?)
  end

  def test_update_returns_false_by_default
    assert_not @policy.send(:update?)
  end

  def test_edit_delegates_to_update
    assert_equal @policy.send(:update?), @policy.send(:edit?)
  end

  def test_destroy_returns_false_by_default
    assert_not @policy.send(:destroy?)
  end
end
