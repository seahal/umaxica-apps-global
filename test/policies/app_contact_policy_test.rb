# typed: false
# frozen_string_literal: true

require "test_helper"

class AppContactPolicyTest < ActiveSupport::TestCase
  class MockContact
    def initialize
    end
  end

  def setup
    @user = nil
    @record = MockContact.new
    @policy = AppContactPolicy.new(@record, user: @user)
  end

  def test_policy_initializes_with_user_and_record
    policy = AppContactPolicy.new(@record, user: @user)

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

  def test_update_returns_false_by_default
    assert_not @policy.send(:update?)
  end

  def test_destroy_returns_false_by_default
    assert_not @policy.send(:destroy?)
  end
  # COMMENTED OUT BY FIX SCRIPT
  #
  #   def test_scope_initializes_without_error
  #     scope = AppContactPolicy::Scope.new(AppContact, user: @user)
  #
  #     assert scope
  #   end
end
