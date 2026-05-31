# typed: false
# frozen_string_literal: true

require "test_helper"

class SignEmailRegistrableIncludedDoTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include CloudflareTurnstile
    include Common::Redirect
    include Common::Otp
    include Sign::EmailRegistrable
  end

  test "terminal controller includes CloudflareTurnstile explicitly" do
    assert_includes Harness.included_modules, CloudflareTurnstile
  end

  test "terminal controller includes Common::Redirect explicitly" do
    assert_includes Harness.included_modules, Common::Redirect
  end

  test "terminal controller includes Common::Otp explicitly" do
    assert_includes Harness.included_modules, Common::Otp
  end

  test "SESSION_KEY constant is defined" do
    assert_equal :sign_up_email_flow_state, Sign::EmailRegistrable::SESSION_KEY
  end

  test "EXISTING_EMAIL_SESSION_KEY constant is defined" do
    assert_equal :sign_up_existing_email_id, Sign::EmailRegistrable::EXISTING_EMAIL_SESSION_KEY
  end

  test "STATE_INIT constant is defined" do
    assert_equal "init", Sign::EmailRegistrable::STATE_INIT
  end

  test "VALID_STATES constant is defined" do
    assert_kind_of Array, Sign::EmailRegistrable::VALID_STATES
  end
end
