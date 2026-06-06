# typed: false
# frozen_string_literal: true

require "test_helper"

class SignEmailRegistrationFlowIncludedDoTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include SignEmailRegistrable
    include CommonRedirect
    include SignEmailRegistrationFlow
  end

  test "terminal controller includes SignEmailRegistrable explicitly" do
    assert_includes Harness.included_modules, SignEmailRegistrable
  end

  test "terminal controller includes CommonRedirect explicitly" do
    assert_includes Harness.included_modules, CommonRedirect
  end

  test "new method exists" do
    assert_includes SignEmailRegistrationFlow.instance_methods(false), :new
  end

  test "edit method exists" do
    assert_includes SignEmailRegistrationFlow.instance_methods(false), :edit
  end
end
