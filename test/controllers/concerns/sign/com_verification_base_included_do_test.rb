# typed: false
# frozen_string_literal: true

require "test_helper"

class SignComVerificationBaseIncludedDoTest < ActiveSupport::TestCase
  test "included do does not include Sign::AppVerificationBase module" do
    klass =
      Class.new(ApplicationController) do
        include Authentication::Base
        include Preference::Base
        include Authentication::Visitor
        include Verification::Visitor
        include Sign::EmailOtpVerificationSupport
        include Sign::ComVerificationBase
      end

    assert_not_includes klass.included_modules, Sign::AppVerificationBase
  end

  test "included do includes visitor verification dependencies directly" do
    klass =
      Class.new(ApplicationController) do
        include Authentication::Base
        include Preference::Base
        include Authentication::Visitor
        include Verification::Visitor
        include Sign::EmailOtpVerificationSupport
        include Sign::ComVerificationBase
      end

    assert_includes klass.included_modules, Authentication::Visitor
    assert_includes klass.included_modules, Verification::Visitor
    assert_includes klass.included_modules, Sign::EmailOtpVerificationSupport
  end
end
