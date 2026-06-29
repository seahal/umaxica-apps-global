# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OperatorTimeBasedTotpCredentialPolicyTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def setup
    @user = nil
    @record = nil
    @policy = OperatorTimeBasedTotpCredentialPolicy.new(@record, user: @user)
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
end
