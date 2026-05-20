# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentifierDetectionTest < ActionDispatch::IntegrationTest
  class DummyController
    include IdentifierDetection
    include EmailValidation

    attr_reader :request

    def initialize
      @request = Struct.new(:remote_ip).new("127.0.0.1")
    end
  end

  setup do
    @controller = DummyController.new
  end

  test "detect_identifier_type returns email for email format" do
    assert_equal :email, @controller.send(:detect_identifier_type, "test@example.com")
  end

  test "detect_identifier_type returns telephone for + prefix" do
    assert_equal :telephone, @controller.send(:detect_identifier_type, "+819012345678")
  end

  test "detect_identifier_type returns unknown for plain text" do
    assert_equal :unknown, @controller.send(:detect_identifier_type, "plaintext")
  end

  test "detect_identifier_type returns unknown for blank input" do
    assert_equal :unknown, @controller.send(:detect_identifier_type, "")
    assert_equal :unknown, @controller.send(:detect_identifier_type, nil)
  end

  test "identity_email_model returns ClientEmail" do
    assert_equal ClientEmail, @controller.send(:identity_email_model)
  end

  test "identity_telephone_model returns ClientTelephone" do
    assert_equal ClientTelephone, @controller.send(:identity_telephone_model)
  end

  test "identity_from_email_record returns nil for nil" do
    assert_nil @controller.send(:identity_from_email_record, nil)
  end

  test "identity_from_telephone_record returns nil for nil" do
    assert_nil @controller.send(:identity_from_telephone_record, nil)
  end
end
