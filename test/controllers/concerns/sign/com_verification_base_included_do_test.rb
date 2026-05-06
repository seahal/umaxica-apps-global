# typed: false
# frozen_string_literal: true

require "test_helper"

class SignComVerificationBaseIncludedDoTest < ActiveSupport::TestCase
  test "included do includes Sign::AppVerificationBase module" do
    klass =
      Class.new(ApplicationController) do
        include Authentication::Base
        include Preference::Base
        include Sign::ComVerificationBase
      end

    assert_includes klass.included_modules, Sign::AppVerificationBase
  end
end
