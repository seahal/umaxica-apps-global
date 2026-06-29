# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# Test suite for preference policies that inherit default behavior from ApplicationPolicy
# These policies don't override any methods, so they use ApplicationPolicy's defaults (all deny)

class AppPreferenceCurrencyPolicyTest < ActiveSupport::TestCase
  def setup
    @user = Client.new
    @record = AppPreferenceCurrency.new
    @policy = AppPreferenceCurrencyPolicy.new(@record, user: @user)
  end

  test "index? is false by default" do
    assert_not @policy.index?
  end

  test "show? is false by default" do
    assert_not @policy.show?
  end

  test "create? is false by default" do
    assert_not @policy.create?
  end

  test "update? is false by default" do
    assert_not @policy.update?
  end

  test "destroy? is false by default" do
    assert_not @policy.destroy?
  end
end

class AppPreferenceLanguagePolicyTest < ActiveSupport::TestCase
  def setup
    @user = Client.new
    @record = AppPreferenceLanguage.new
    @policy = AppPreferenceLanguagePolicy.new(@record, user: @user)
  end

  test "index? is false by default" do
    assert_not @policy.index?
  end

  test "show? is false by default" do
    assert_not @policy.show?
  end

  test "create? is false by default" do
    assert_not @policy.create?
  end

  test "update? is false by default" do
    assert_not @policy.update?
  end

  test "destroy? is false by default" do
    assert_not @policy.destroy?
  end
end

class AppPreferenceThemePolicyTest < ActiveSupport::TestCase
  def setup
    @user = Client.new
    @record = AppPreferenceTheme.new
    @policy = AppPreferenceThemePolicy.new(@record, user: @user)
  end

  test "index? is false by default" do
    assert_not @policy.index?
  end

  test "show? is false by default" do
    assert_not @policy.show?
  end

  test "create? is false by default" do
    assert_not @policy.create?
  end

  test "update? is false by default" do
    assert_not @policy.update?
  end

  test "destroy? is false by default" do
    assert_not @policy.destroy?
  end
end

class AppPreferenceTimezonePolicyTest < ActiveSupport::TestCase
  def setup
    @user = Client.new
    @record = AppPreferenceTimezone.new
    @policy = AppPreferenceTimezonePolicy.new(@record, user: @user)
  end

  test "index? is false by default" do
    assert_not @policy.index?
  end

  test "show? is false by default" do
    assert_not @policy.show?
  end

  test "create? is false by default" do
    assert_not @policy.create?
  end

  test "update? is false by default" do
    assert_not @policy.update?
  end

  test "destroy? is false by default" do
    assert_not @policy.destroy?
  end
end

class AppPreferenceRegionPolicyTest < ActiveSupport::TestCase
  def setup
    @user = Client.new
    @record = AppPreferenceRegion.new
    @policy = AppPreferenceRegionPolicy.new(@record, user: @user)
  end

  test "index? is false by default" do
    assert_not @policy.index?
  end

  test "show? is false by default" do
    assert_not @policy.show?
  end

  test "create? is false by default" do
    assert_not @policy.create?
  end

  test "update? is false by default" do
    assert_not @policy.update?
  end

  test "destroy? is false by default" do
    assert_not @policy.destroy?
  end
end
