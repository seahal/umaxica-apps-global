# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../app/models/concerns/accountable"
require_relative "../../app/models/user"
require_relative "../../app/models/staff"

class AccountableTest < ActiveSupport::TestCase
  { "User" => ::User, "Staff" => ::Staff }.each do |_klass_name, klass|
    test "#{klass} is a ..." do
      assert_includes klass.included_modules, ::Accountable
    end
  end

  test "user and staff are different classes" do
    assert_not_equal ::User, ::Staff
  end

  test "should raise NotImplementedError for staff?" do
    dummy = Object.new
    dummy.extend(::Accountable)

    error =
      assert_raises(NotImplementedError) do
        dummy.staff?
      end
    assert_match(/must implement staff\? method/, error.message)
  end

  test "should raise NotImplementedError for user?" do
    dummy = Object.new
    dummy.extend(::Accountable)

    error =
      assert_raises(NotImplementedError) do
        dummy.user?
      end
    assert_match(/must implement user\? method/, error.message)
  end
end
