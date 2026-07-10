# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class EmailValidationCoverageTest < ActiveSupport::TestCase
  class TestController
    include EmailValidation
  end

  setup do
    @validator = TestController.new
  end

  test "valid_email?" do
    # EmailValidation concern uses JitUtilsEmailValidator
    assert JitUtilsEmailValidator.valid?("test@example.com")
    assert_not JitUtilsEmailValidator.valid?("invalid")
  end

  test "validate_and_normalize_email" do
    assert_equal "test@example.com", JitUtilsEmailValidator.normalize(" TEST@example.com ")
    assert_nil JitUtilsEmailValidator.normalize("invalid")
  end
end
