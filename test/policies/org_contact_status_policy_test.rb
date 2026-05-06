# typed: false
# frozen_string_literal: true

require "test_helper"

class OrgContactStatusPolicyTest < ActiveSupport::TestCase
  def setup
    @user = nil
    @record = nil
    @policy = OrgContactStatusPolicy.new(@record, user: @user)
  end

  def test_index
    assert_not @policy.index?
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
  # COMMENTED OUT BY FIX SCRIPT
  #
  #   def test_scope
  #     scope = OrgContactStatusPolicy::Scope.new(nil, user: @user)
  #     assert_raises(NoMethodError) { scope.resolve }
  #   end
end
