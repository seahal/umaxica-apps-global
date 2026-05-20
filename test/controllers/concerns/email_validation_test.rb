# typed: false
# frozen_string_literal: true

require "test_helper"

class EmailValidationTest < ActionDispatch::IntegrationTest
  class DummyController
    include EmailValidation

    attr_reader :request

    def initialize
      @request = Struct.new(:remote_ip).new("127.0.0.1")
    end
  end

  setup do
    @controller = DummyController.new
  end

  test "validate_and_normalize_email calls EmailValidator.normalize" do
    result = @controller.send(:validate_and_normalize_email, "Test@Example.com")

    assert_equal "test@example.com", result
  end

  test "valid_email_format? returns true for valid email" do
    assert @controller.send(:valid_email_format?, "test@example.com")
  end

  test "valid_email_format? returns false for invalid email" do
    assert_not @controller.send(:valid_email_format?, "invalid-email")
  end

  test "identity_email_model returns ClientEmail" do
    assert_equal ClientEmail, @controller.send(:identity_email_model)
  end
end
