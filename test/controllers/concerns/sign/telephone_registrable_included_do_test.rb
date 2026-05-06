# typed: false
# frozen_string_literal: true

require "test_helper"

class SignTelephoneRegistrableIncludedDoTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include Sign::TelephoneRegistrable
  end

  test "included do includes Common::Redirect module" do
    assert_includes Harness.included_modules, Common::Redirect
  end

  test "included do includes Common::Otp module" do
    assert_includes Harness.included_modules, Common::Otp
  end

  test "TELEPHONE_VERIFICATION_RATE_LIMIT constant is defined" do
    assert_equal 5, Sign::TelephoneRegistrable::TELEPHONE_VERIFICATION_RATE_LIMIT
  end

  test "TELEPHONE_VERIFICATION_RATE_WINDOW constant is defined" do
    assert_equal 60, Sign::TelephoneRegistrable::TELEPHONE_VERIFICATION_RATE_WINDOW
  end

  test "initiate_telephone_verification method exists" do
    harness = Harness.new

    assert_respond_to(harness, :initiate_telephone_verification)
  end
end
