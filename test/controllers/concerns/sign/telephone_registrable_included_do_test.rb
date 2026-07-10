# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SignTelephoneRegistrableIncludedDoTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include CommonRedirect
    include CommonOtp
    include SignTelephoneRegistrable
  end

  test "terminal controller includes CommonRedirect explicitly" do
    assert_includes Harness.included_modules, CommonRedirect
  end

  test "terminal controller includes CommonOtp explicitly" do
    assert_includes Harness.included_modules, CommonOtp
  end

  test "TELEPHONE_VERIFICATION_RATE_LIMIT constant is defined" do
    assert_equal 5, SignTelephoneRegistrable::TELEPHONE_VERIFICATION_RATE_LIMIT
  end

  test "TELEPHONE_VERIFICATION_RATE_WINDOW constant is defined" do
    assert_equal 60, SignTelephoneRegistrable::TELEPHONE_VERIFICATION_RATE_WINDOW
  end

  test "initiate_telephone_verification method exists" do
    harness = Harness.new

    assert_respond_to(harness, :initiate_telephone_verification)
  end
end
