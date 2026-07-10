# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "jit_utils_email_validator"

module Jit
  module Utils
    class EmailValidatorTest < ActiveSupport::TestCase
      test "normalize returns nil for blank email" do
        assert_nil JitUtilsEmailValidator.normalize(nil)
        assert_nil JitUtilsEmailValidator.normalize("")
        assert_nil JitUtilsEmailValidator.normalize("  ")
      end

      test "normalize downcases and strips email" do
        assert_equal "user@example.com", JitUtilsEmailValidator.normalize(" USER@Example.COM ")
      end

      test "normalize returns nil for invalid email" do
        assert_nil JitUtilsEmailValidator.normalize("invalid-email")
        assert_nil JitUtilsEmailValidator.normalize("user@")
        assert_nil JitUtilsEmailValidator.normalize("@example.com")
      end

      test "valid? returns true for valid email" do
        assert JitUtilsEmailValidator.valid?("user@example.com")
        assert JitUtilsEmailValidator.valid?("user.name+tag@example.co.jp")
      end

      test "valid? returns false for invalid email" do
        assert_not JitUtilsEmailValidator.valid?("invalid")
        assert_not JitUtilsEmailValidator.valid?("")
        assert_not JitUtilsEmailValidator.valid?(nil)
      end
    end
  end
end
