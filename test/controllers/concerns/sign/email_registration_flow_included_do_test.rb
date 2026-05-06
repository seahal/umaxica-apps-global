# typed: false
# frozen_string_literal: true

require "test_helper"

class SignEmailRegistrationFlowIncludedDoTest < ActiveSupport::TestCase
  class Harness < ApplicationController
    include Sign::EmailRegistrationFlow
  end

  test "included do includes Sign::EmailRegistrable module" do
    assert_includes Harness.included_modules, Sign::EmailRegistrable
  end

  test "included do includes Common::Redirect module" do
    assert_includes Harness.included_modules, Common::Redirect
  end

  test "new method exists" do
    assert_includes Sign::EmailRegistrationFlow.instance_methods(false), :new
  end

  test "edit method exists" do
    assert_includes Sign::EmailRegistrationFlow.instance_methods(false), :edit
  end
end
