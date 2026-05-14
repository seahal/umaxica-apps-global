# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: user_token_binding_methods
# Database name: mark
#
#  id :bigint           not null, primary key
#
require "test_helper"

class UserTokenBindingMethodTest < ActiveSupport::TestCase
  test "constants are defined correctly" do
    assert_equal 0, UserTokenBindingMethod::NOTHING
    assert_equal 1, UserTokenBindingMethod::DBSC
    assert_equal 2, UserTokenBindingMethod::LEGACY
    assert_equal [0, 1, 2], UserTokenBindingMethod::DEFAULTS
  end

  test "ensure_defaults! creates missing records" do
    Prosopite.pause do
      UserTokenBindingMethod.where(id: UserTokenBindingMethod::DEFAULTS).destroy_all
    end

    UserTokenBindingMethod.ensure_defaults!

    assert UserTokenBindingMethod.exists?(id: UserTokenBindingMethod::NOTHING)
    assert UserTokenBindingMethod.exists?(id: UserTokenBindingMethod::DBSC)
    assert UserTokenBindingMethod.exists?(id: UserTokenBindingMethod::LEGACY)
  end

  test "ensure_defaults! does nothing when all defaults exist" do
    UserTokenBindingMethod.ensure_defaults!
    initial_count = UserTokenBindingMethod.count

    UserTokenBindingMethod.ensure_defaults!

    assert_equal initial_count, UserTokenBindingMethod.count
  end

  test "has_many user_tokens association" do
    method = UserTokenBindingMethod.new(id: 1)

    assert_respond_to method, :user_tokens
  end
end
