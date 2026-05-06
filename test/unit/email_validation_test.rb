# typed: false
# frozen_string_literal: true

require "test_helper"

class EmailValidationCoverageTest < ActiveSupport::TestCase
  class TestController
    include EmailValidation
  end

  setup do
    @validator = TestController.new
  end

  test "valid_email?" do
    # EmailValidation concern uses Jit::Utils::EmailValidator
    assert Jit::Utils::EmailValidator.valid?("test@example.com")
    assert_not Jit::Utils::EmailValidator.valid?("invalid")
  end

  test "validate_and_normalize_email" do
    assert_equal "test@example.com", Jit::Utils::EmailValidator.normalize(" TEST@example.com ")
    assert_nil Jit::Utils::EmailValidator.normalize("invalid")
  end
end
